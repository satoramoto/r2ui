# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require_relative "../../examples/diskinv/scanner"
require_relative "../../examples/diskinv/treemap"

# examples/diskinv.rb: the scanner, the index and the treemap layout.
class DiskInvTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    write("big.mov", 6000)
    write("notes.txt", 1000)
    write("src/a.rb", 2000)
    write("src/b.rb", 1000)
    write("src/deep/c.rb", 0)
    File.symlink(File.join(@dir, "big.mov"), File.join(@dir, "link.mov"))
    @scanner = DiskInv::Scanner.new(@dir)
    @scanner.scan
    @index = DiskInv::Index.new(@scanner.snapshot.rows)
  end

  def teardown = FileUtils.remove_entry(@dir)

  def write(name, bytes)
    path = File.join(@dir, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "x" * bytes)
  end

  def test_scan_finds_files_and_folders_but_not_symlinks
    snap = @scanner.snapshot

    assert snap.done
    assert_equal %w[a.rb b.rb big.mov c.rb deep notes.txt src], snap.rows.drop(1).map(&:name).sort
  end

  def test_index_sums_subtrees_and_ranks_kinds_by_size
    assert_equal 10_000, @index.size(@dir)
    assert_equal 5, @index.files(@dir)
    assert_equal 3000, @index.size(File.join(@dir, "src"))
    assert_equal %w[mov rb txt], @index.kinds.map(&:name)
    assert_equal [3000, 3], [@index.kinds[1].bytes, @index.kinds[1].files]
    assert_equal [@dir, File.join(@dir, "src"), File.join(@dir, "src/deep")], @index.ancestors(File.join(@dir, "src/deep/c.rb"))
  end

  def test_treemap_gives_each_file_an_area_in_proportion_to_its_size
    map = DiskInv::Treemap.new(@index, @dir, 40, 10)
    counts = Hash.new(0)
    10.times { |y| 40.times { |x| counts[map.at(x, y)&.name] += 1 } }

    assert_equal 400, counts.values.sum
    assert_equal 0, counts[nil], "every cell is filled"
    assert_in_delta 240, counts["big.mov"], 20
    assert_in_delta 80, counts["a.rb"], 20
    refute counts.key?("c.rb"), "empty files take no space"
  end

  def test_scanning_a_missing_folder_gives_a_done_snapshot_with_an_error
    scanner = DiskInv::Scanner.new(File.join(@dir, "missing"))
    scanner.scan
    snap = scanner.snapshot

    assert snap.done
    assert_match(/No such file/, snap.error)
  end

  def test_treemap_labels_never_write_escapes_or_wide_characters
    write("\e[31mred", 5000)
    write("日本.txt", 5000)
    scanner = DiskInv::Scanner.new(@dir)
    scanner.scan
    lines = DiskInv::Treemap.new(DiskInv::Index.new(scanner.snapshot.rows), @dir, 60, 12).lines

    lines.each do |l|
      plain = l.gsub(/\e\[[0-9;]*m/, "")
      refute_includes plain, "\e"
      assert_equal 60, R2UI::Compat::Tea::ANSI.string_width(plain)
      assert_equal 60, plain.length
    end
    assert(lines.any? { |l| l.include?("?[31mred") })
  end

  def test_treemap_outlines_the_selection_or_the_folder_it_is_drawn_in
    map = DiskInv::Treemap.new(@index, @dir, 40, 10)
    src = map.rect(File.join(@dir, "src"))

    refute_nil src
    assert_equal src, map.rect(File.join(@dir, "src/deep/c.rb")), "empty, so drawn as part of src"
    plain = map.lines(File.join(@dir, "src")).map { |l| l.gsub(/\e\[[0-9;]*m/, "") }

    assert_equal "┏", plain[src[1]][src[0]]
  end
end
