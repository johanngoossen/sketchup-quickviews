require 'sketchup.rb'

module JG
  module QuickViews
    FILES = %w[l10n presets filename_pattern frame_math frame_overlay exporter dialog].freeze
    PREFS = 'QuickViews'.freeze
    LEGACY_PREFS = 'JViews'.freeze # name during development

    FILES.each { |f| require File.join(PLUGIN_DIR, f) }

    # Reloads all Ruby files without restarting SketchUp (development).
    # Menu and toolbar stay as they are; their commands call the reloaded code.
    def self.reload
      Dialog.close
      original_verbose = $VERBOSE
      $VERBOSE = nil
      FILES.each { |f| load File.join(PLUGIN_DIR, "#{f}.rb") }
      $VERBOSE = original_verbose
      FrameOverlay.apply_to(Sketchup.active_model)
      puts L10n.t('reloaded', version: VERSION, count: FILES.size)
      FILES.size
    end

    def self.icon(name)
      ext = Sketchup.platform == :platform_osx ? 'pdf' : 'svg'
      File.join(PLUGIN_DIR, 'icons', "#{name}.#{ext}")
    end

    def self.dev_mode?
      defined?(QUICKVIEWS_DEV_SRC) ? true : false
    end

    # Takes over settings saved under the development name "JViews" once.
    def self.migrate_prefs
      %w[presets active_preset pattern existing last_dir frame_opacity].each do |key|
        next unless Sketchup.read_default(PREFS, key).nil?

        old = Sketchup.read_default(LEGACY_PREFS, key)
        Sketchup.write_default(PREFS, key, old) unless old.nil?
      end
    end

    unless file_loaded?(__FILE__)
      migrate_prefs

      cmd_dialog = UI::Command.new(L10n.t('menu.export')) { Dialog.show }
      cmd_dialog.tooltip = L10n.t('menu.export.tip')
      cmd_dialog.status_bar_text = L10n.t('menu.export.status')
      cmd_dialog.small_icon = cmd_dialog.large_icon = icon('export')

      cmd_frame = UI::Command.new(L10n.t('menu.frame')) { FrameOverlay.toggle }
      cmd_frame.tooltip = L10n.t('menu.frame.tip')
      cmd_frame.status_bar_text = L10n.t('menu.frame.status')
      cmd_frame.small_icon = cmd_frame.large_icon = icon('frame')
      cmd_frame.set_validation_proc do
        next MF_GRAYED unless FrameOverlay.supported?

        FrameOverlay.enabled? ? MF_CHECKED : MF_UNCHECKED
      end

      menu = UI.menu('Extensions').add_submenu(NAME)
      menu.add_item(cmd_dialog)
      menu.add_item(cmd_frame)
      if dev_mode?
        menu.add_separator
        menu.add_item(L10n.t('menu.reload')) { QuickViews.reload }
      end

      toolbar = UI::Toolbar.new(NAME)
      toolbar.add_item(cmd_dialog)
      toolbar.add_item(cmd_frame)
      toolbar.restore

      if FrameOverlay.supported?
        Sketchup.add_observer(FrameOverlay::AppObserver.new)
        FrameOverlay.apply_to(Sketchup.active_model)
      end

      file_loaded(__FILE__)
    end
  end
end
