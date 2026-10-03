# frozen_string_literal: true

require "set"

module R2UI
  # What the viewer has chosen for one table panel: scope, grouping, sort, search, selection.
  class PanelState
    attr_accessor :search
    attr_reader :sort, :selected, :offset, :collapsed
    # For tables with motion: the id of the selected line in the last frame, each line id's index
    # in the last frame (nil before the first), and the gutter mark (:up, :down, :new) per line id.
    attr_reader :selected_id, :positions, :marks

    def initialize(resource, table = nil)
      @resource = resource
      @scope_index = index_of(resource.scopes, table&.scope) || resource.scopes.index(resource.default_scope)
      @group_index = index_of(resource.groupings, table&.group_by)
      @sort = normalize_sort(table&.sort) || resource.default_sort
      @search = ""
      @selected = 0
      @offset = 0
      @collapsed = Set.new
      @selected_id = nil
      @positions = nil
      @marks = {}
    end

    # Keeps the selection on the same line when lines re-sort: if the line selected last frame is
    # now at another index, the selection moves there. Then remembers the selected line's id.
    def follow_selection(lines)
      if @selected_id && (index = lines.index { |l| l.id == @selected_id }) && index != @selected
        @selected = index
      end
      @selected_id = lines[@selected.clamp(0, [lines.size - 1, 0].max)]&.id
    end

    # Records where each line is this frame. Lines that moved since the last frame get an :up or
    # :down mark, lines not there before a :new mark; the first frame (or one after the view
    # changed: scope, grouping, sort, search) marks nothing. Returns the new marks ({id => kind}).
    def track_positions(lines)
      signature = [@scope_index, @group_index, @sort, @search]
      current = {}
      lines.each_with_index { |line, i| current[line.id] = i }
      changes = {}
      if @positions && signature == @positions_signature
        current.each do |id, i|
          before = @positions[id]
          if before.nil? then changes[id] = :new
          elsif before != i then changes[id] = i < before ? :up : :down
          end
        end
      end
      @positions = current
      @positions_signature = signature
      @marks.select! { |id, _| current.key?(id) }
      @marks.merge!(changes)
      changes
    end

    def scope = @scope_index && @resource.scopes[@scope_index]

    def grouping = @group_index && @resource.groupings[@group_index]

    def scope_tabs = @resource.scopes.each_with_index.map { |s, i| [s.label, i == @scope_index] }

    def cycle_scope(step)
      return if @resource.scopes.empty?

      @scope_index = ((@scope_index || 0) + step) % @resource.scopes.size
      reset_position
    end

    # Off → each grouping in turn → off.
    def cycle_grouping
      count = @resource.groupings.size
      return if count.zero?

      @group_index = @group_index.nil? ? 0 : (@group_index + 1 < count ? @group_index + 1 : nil)
      reset_position
    end

    # Next column; numbers sort descending first, text ascending.
    def cycle_sort
      keys = @resource.columns.map(&:key)
      current = keys.index(@sort&.first)
      key = keys[current.nil? ? 0 : (current + 1) % keys.size]
      @sort = [key, @resource.column(key).numeric? ? :desc : :asc]
    end

    def reverse_sort
      @sort = [@sort.first, @sort.last == :desc ? :asc : :desc] if @sort
    end

    def move(delta, count)
      @selected = (@selected + delta).clamp(0, [count - 1, 0].max)
      @selected_id = nil
    end

    def toggle(line)
      return unless line&.expandable?

      @collapsed.include?(line.id) ? @collapsed.delete(line.id) : @collapsed.add(line.id)
    end

    def scroll_to_selection(height, count)
      @selected = @selected.clamp(0, [count - 1, 0].max)
      @offset = @selected if @selected < @offset
      @offset = @selected - height + 1 if height.positive? && @selected >= @offset + height
      @offset = @offset.clamp(0, [count - height, 0].max)
    end

    def status
      parts = []
      parts << "group: #{grouping.label}" if grouping
      parts << "sort: #{@resource.column(sort.first)&.label}#{sort.last == :desc ? "▼" : "▲"}" if sort
      parts << "search: #{search}" unless search.empty?
      parts.join("  ")
    end

    private

    def reset_position
      @selected = 0
      @selected_id = nil
      @offset = 0
    end

    def index_of(list, name) = name && list.index { |item| item.name == name }

    def normalize_sort(sort)
      case sort
      when nil then nil
      when Array then sort
      else [sort, @resource.column(sort)&.numeric? ? :desc : :asc]
      end
    end
  end
end
