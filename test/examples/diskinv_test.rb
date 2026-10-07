# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require_relative "../../examples/diskinv/scanner"
require_relative "../../examples/diskinv/treemap"

# examples/diskinv.rb: the scanner, its tree and the treemap layout.
class DiskInvTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    write("big.mov", 6000)
    write("notes.txt", 1000)
    write("src/a.rb", 2000)
    write("src/b.rb", 1000)
    write("src/deep/c.rb", 0)
    File.symlink(File.join(@dir, "big.mov"), File.join(@dir, "link.mov"))
    @snap = scan
  end

  def teardown = FileUtils.remove_entry(@dir)

  def write(name, bytes)
    path = File.join(@dir, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "x" * bytes)
  end

  # Logical sizes by default, so the numbers don't depend on the file system's block size.
  def scan(dir = @dir, workers: 2, sizes: :logical)
    scanner = DiskInv::Scanner.new(dir, workers:, sizes:)
    scanner.scan
    scanner.snapshot
  end

  def find(node, rel) = rel.split("/").reduce(node) { |n, name| n.children.find { |k| k.name == name } }
  def names(node) = node.children.to_a.flat_map { |k| [k.name, *names(k).map { |n| "#{k.name}/#{n}" }] }.sort
  def treemap(snap, width, height) = DiskInv::Treemap.new(snap.root, width, height, colors: snap.colors)

  def test_scan_finds_files_and_folders_but_not_symlinks
    assert @snap.done
    assert_equal %w[big.mov notes.txt src src/a.rb src/b.rb src/deep src/deep/c.rb], names(@snap.root)
    assert_equal File.join(@dir, "src/deep/c.rb"), find(@snap.root, "src/deep/c.rb").path
  end

  def test_the_walkers_and_the_inline_walk_build_the_same_tree
    inline = scan(workers: 0)

    assert_equal names(@snap.root), names(inline.root)
    assert_equal @snap.root.size, inline.root.size
  end

  def test_folders_sum_their_subtrees_and_kinds_rank_by_size
    root = @snap.root

    assert_equal [10_000, 5], [root.size, root.files]
    assert_equal [3000, 3], [find(root, "src").size, find(root, "src").files]
    assert_equal %w[mov rb txt], @snap.kinds.map(&:name)
    assert_equal [3000, 3], [@snap.kinds[1].bytes, @snap.kinds[1].files]
    assert_equal [root, find(root, "src"), find(root, "src/deep")], find(root, "src/deep/c.rb").ancestors
  end

  # A sparse file reports a size with no blocks allocated, like an online-only cloud file.
  def test_disk_sizes_count_cloud_only_files_as_nothing
    File.open(File.join(@dir, "drive.mov"), "w") { |f| f.truncate(50_000_000) }
    skip "this file system allocates blocks for sparse files" unless File.lstat(File.join(@dir, "drive.mov")).blocks.zero?

    disk = scan(sizes: :disk)
    logical = scan

    assert_equal 0, find(disk.root, "drive.mov").size
    assert_operator disk.root.size, :<, 1_000_000, "the real files only, rounded up to blocks"
    assert_equal [1, 50_000_000], [disk.cloud_files, disk.cloud_bytes]
    assert_equal 50_010_000, logical.root.size
    assert_equal [1, 50_000_000], [logical.cloud_files, logical.cloud_bytes]
    assert_equal %i[disk logical], [disk.sizes, logical.sizes]
  end

  # macOS compresses tiny files into their metadata, so they report 0 blocks too; they aren't cloud files.
  def test_small_zero_block_files_are_not_cloud_only
    path = File.join(@dir, "tiny.dat")
    File.open(path, "w") { |f| f.truncate(DiskInv::Scanner::CLOUD_MIN) }
    skip "this file system allocates blocks for sparse files" unless File.lstat(path).blocks.zero?

    snap = scan(sizes: :disk)

    assert_equal [0, 0], [snap.cloud_files, snap.cloud_bytes]
  end

  def test_scanning_a_missing_folder_gives_a_done_snapshot_with_an_error
    snap = scan(File.join(@dir, "missing"))

    assert snap.done
    assert_match(/No such file/, snap.error)
  end

  def test_treemap_gives_each_file_an_area_in_proportion_to_its_size
    map = treemap(@snap, 40, 10)
    counts = Hash.new(0)
    10.times { |y| 40.times { |x| counts[map.at(x, y)&.name] += 1 } }

    assert_equal 0, counts[nil], "every cell is filled"
    assert_in_delta 240, counts["big.mov"], 20
    assert_in_delta 80, counts["a.rb"], 20
    refute counts.key?("c.rb"), "empty files take no space"
  end

  def test_treemap_lays_out_a_folder_whose_size_lags_its_children_mid_scan
    root = DiskInv::Node.new("/r", nil, true, 0, 0, nil, [])
    root.children << DiskInv::Node.new("f.txt", root, false, 500, 1, "Text", nil)
    map = DiskInv::Treemap.new(root, 20, 6)

    assert(6.times.all? { |y| 20.times.all? { |x| map.at(x, y) } }, "every cell is filled")
  end

  def test_treemap_labels_never_write_escapes_or_wide_characters
    write("\e[31mred", 5000)
    write("日本.txt", 5000)
    lines = treemap(scan, 60, 12).lines

    lines.each do |l|
      plain = l.gsub(/\e\[[0-9;]*m/, "")
      refute_includes plain, "\e"
      assert_equal 60, R2UI::Compat::Tea::ANSI.string_width(plain)
      assert_equal 60, plain.length
    end
    assert(lines.any? { |l| l.include?("?[31mred") })
  end

  def test_treemap_outlines_the_selection_or_the_folder_it_is_drawn_in
    map = treemap(@snap, 40, 10)
    src = find(@snap.root, "src")
    rect = map.rect(src)

    refute_nil rect
    assert_equal rect, map.rect(find(src, "deep/c.rb")), "empty, so drawn as part of src"
    plain = map.lines(src).map { |l| l.gsub(/\e\[[0-9;]*m/, "") }

    assert_equal "┏", plain[rect[1]][rect[0]]
    refute_includes map.lines.join, "┏", "nothing selected, no outline"
  end

  # The first frame comes before the tree has a line to select.
  def test_the_dashboard_draws_before_anything_is_selected
    R2UI.reset!
    ENV["DISKINV_ROOT"] = @dir
    load File.expand_path("../../examples/diskinv.rb", __dir__) unless defined?(DiskInv::ROOT)
    app = R2UI::App.new(R2UI.registry)

    assert_nil DiskInv.selected(app)
    assert_match(/Treemap/, app.frame(100, 30).plain_lines.join("\n"))
    assert_match(/Treemap/, app.frame(100, 30).plain_lines.join("\n"), "and again from the cache")
  ensure
    ENV.delete("DISKINV_ROOT")
    R2UI.reset!
  end
end
