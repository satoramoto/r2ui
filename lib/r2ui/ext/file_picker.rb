# frozen_string_literal: true

# s31-file-picker: a file browser in a panel (bubbles' FilePicker).
#
#   R2UI.dashboard do
#     row do
#       panel :files, resource: nil do
#         file_picker :browser, dir: ".", allowed: %w[.rb .md],
#                               on_select: ->(path) { state[:open] = path; flash "picked #{path}" }
#       end
#     end
#   end
#
# Hosts a `Bubbles::FilePicker` on `dir` (default "."), sized to the panel's height. While the
# panel has focus the picker takes the keys: up/down (k/j), pgup/pgdown, home/end (g/G),
# enter/right (l) to open a directory or select a file, left (h)/backspace to go back up.
# `allowed` lists the selectable extensions, with or without the dot; empty (the default) allows
# every file. `on_select` runs on a Context with the selected file's absolute path, once per
# selection; a command it returns runs. `component(:browser)` is the picker itself.
module R2UI
  module Ext
    module FilePicker
      Item = Data.define(:name, :dir, :allowed, :on_select)

      module_function

      # The bubbles model for `item`. Each selection it makes is pushed onto `selections` as
      # [item, path], for the after_update hook to hand to on_select.
      def build(item, selections)
        picker = Bubbles::FilePicker.new(directory: item.dir)
        picker.allowed_types = item.allowed.map { |ext| ext.to_s.delete_prefix(".") }
        picker.singleton_class.prepend(Module.new do
          define_method(:update) do |message|
            super(message).tap { selections << [item, path] if did_select_file? }
          end
        end)
        picker
      end

      # Fits the listing under the picker's two header lines (path, blank).
      def fit(picker, height)
        rows = [height - 2, 1].max
        return if picker.height == rows

        picker.height = rows
        picker.send(:update_offset) if picker.respond_to?(:update_offset, true)
      end
    end
  end

  extension :file_picker do
    dsl :panel do
      def file_picker(name, dir: ".", allowed: [], on_select: nil)
        Component.require_bubbles!
        item(Ext::FilePicker::Item.new(name: name.to_sym, dir: dir.to_s, allowed: Array(allowed), on_select:))
      end
    end

    component(Ext::FilePicker::Item, focusable: true) do |item|
      Ext::FilePicker.build(item, store(:file_picker)[:selections] ||= [])
    end

    after_update do
      selections = store(:file_picker)[:selections]
      while (item, path = selections&.shift)
        call(item.on_select, path) if item.on_select
      end
    end

    panel_item(Ext::FilePicker::Item) do |item|
      instance = app.components.find { |c| c.item.equal?(item) && c.panel == panel }
      next "" unless instance

      Ext::FilePicker.fit(instance.model, height)
      instance.model.view
    end
  end
end
