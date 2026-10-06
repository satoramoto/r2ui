# frozen_string_literal: true

require_relative "treemap"

module DiskInv
  # One file or folder. Folders have size 0 and files 0 of their own; the tree sums their subtree.
  Entry = Data.define(:path, :parent, :name, :size, :files, :kind, :dir) do
    def dir? = dir
  end

  # Walks a folder in a background thread and publishes a snapshot of what it has found so far,
  # indexed, so the dashboard fills in while it scans. Indexing a big tree takes a while, so
  # snapshots come at most every PUBLISH seconds and the scan keeps at least 80% of the time.
  # Symlinks are skipped and the walk stays on the root's volume, like Disk Inventory X.
  class Scanner
    PUBLISH = 0.25
    Snapshot = Data.define(:rows, :index, :done, :seconds, :errors, :error)

    attr_reader :root

    def initialize(root)
      @root = File.expand_path(root)
      @lock = Mutex.new
      @snapshot = Snapshot.new(rows: [].freeze, index: Index.new([]), done: false, seconds: 0.0, errors: 0,
                               error: nil)
      @wait = PUBLISH
    end

    def snapshot = @lock.synchronize { @snapshot }

    def start
      @thread ||= Thread.new { scan }
      self
    end

    # Scans in the calling thread (tests, snapshots). If the root itself can't be read, publishes a
    # done snapshot carrying the error.
    def scan
      walk
    rescue SystemCallError => e
      snap = Snapshot.new(rows: [].freeze, index: Index.new([]), done: true, seconds: 0.0, errors: 1,
                          error: e.message)
      @lock.synchronize { @snapshot = snap }
    end

    private

    def walk
      started = clock
      published = started
      rows = [entry(@root, nil, File.basename(@root), 0, dir: true)]
      errors = 0
      device = File.lstat(@root).dev
      pending = [@root]
      until pending.empty?
        dir = pending.pop
        begin
          children = Dir.children(dir)
        rescue SystemCallError
          errors += 1
          next
        end
        children.each do |name|
          path = File.join(dir, name)
          stat = begin
            File.lstat(path)
          rescue SystemCallError
            errors += 1
            next
          end
          next if stat.symlink?

          if stat.directory?
            next unless stat.dev == device

            rows << entry(path, dir, name, 0, dir: true)
            pending << path
          elsif stat.file?
            rows << entry(path, dir, name, stat.size, dir: false)
          end
        end
        if clock - published > @wait
          publish(rows, false, clock - started, errors)
          published = clock
        end
      end
      publish(rows, true, clock - started, errors)
    end

    def entry(path, parent, name, size, dir:)
      Entry.new(path:, parent:, name:, size:, files: dir ? 0 : 1, kind: dir ? nil : DiskInv.kind(name), dir:)
    end

    def publish(rows, done, seconds, errors)
      began = clock
      rows = rows.dup.freeze
      snap = Snapshot.new(rows:, index: Index.new(rows), done:, seconds:, errors:, error: nil)
      @wait = [PUBLISH, (clock - began) * 4].max
      @lock.synchronize { @snapshot = snap }
    end

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # A file's kind: its lowercased extension, or "(none)".
  def self.kind(name)
    ext = File.extname(name)
    ext.empty? || ext == name ? "(none)" : ext.delete_prefix(".").downcase
  end
end
