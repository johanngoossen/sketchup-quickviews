module JG
  module QuickViews
    # UI language: German when SketchUp runs in German (SketchUp follows the
    # system language), English otherwise. The dialog gets the same choice.
    module L10n
      STRINGS = {
        'en' => {
          'ext.description' => 'Exports all or selected scenes as images in one run, with presets, ' \
                               'file name patterns and a frame preview in the viewport.',
          'menu.export' => 'Export Scenes …',
          'menu.export.tip' => 'Quick Views: Export scenes',
          'menu.export.status' => 'Export all or selected scenes as images.',
          'menu.frame' => 'Frame Preview',
          'menu.frame.tip' => 'Quick Views: Frame preview on/off',
          'menu.frame.status' => 'Shows the image area of the active preset in the viewport.',
          'menu.reload' => 'Reload (development)',
          'dialog.title' => 'Quick Views – Export Scenes',
          'overlay.name' => 'Quick Views Frame',
          'overlay.description' => 'Shows the image area of the active Quick Views preset.',
          'preset.new' => 'New Preset',
          'preset.rename' => 'Rename Preset',
          'preset.copy' => '%{name} (copy)',
          'preset.delete_confirm' => 'Delete preset “%{name}”?',
          'preset.name' => 'Name',
          'preset.untitled' => 'Untitled',
          'preset.builtin_readonly' => 'Built-in presets cannot be changed.',
          'preset.builtin_undeletable' => 'Built-in presets cannot be deleted.',
          'preset.not_found' => 'Preset not found or cannot be renamed.',
          'preset.viewport' => 'Viewport (current window size)',
          'preset.a4_landscape' => 'A4 landscape, 300 dpi',
          'preset.a4_portrait' => 'A4 portrait, 300 dpi',
          'preset.a3_landscape' => 'A3 landscape, 300 dpi',
          'preset.square' => 'Square',
          'dir.choose' => 'Choose output folder',
          'dir.remember' => 'Quick Views: Remember output folder',
          'model.untitled' => 'Untitled',
          'scene.default' => 'Scene',
          'error.running' => 'An export is already running.',
          'error.no_scenes' => 'No scenes selected.',
          'error.no_dir' => 'Please choose an output folder.',
          'error.dir_not_writable' => 'Folder is not writable: %{dir}',
          'error.write_failed' => 'write_image failed (resolution too high for the graphics card?)',
          'reloaded' => 'Quick Views %{version} reloaded (%{count} files).',
        },
        'de' => {
          'ext.description' => 'Exportiert alle oder ausgewählte Szenen in einem Durchlauf als Bilder, ' \
                               'mit Presets, Dateinamen-Muster und Rahmenvorschau im Viewport.',
          'menu.export' => 'Szenen exportieren …',
          'menu.export.tip' => 'Quick Views: Szenen exportieren',
          'menu.export.status' => 'Alle oder ausgewählte Szenen als Bilder exportieren.',
          'menu.frame' => 'Rahmenvorschau',
          'menu.frame.tip' => 'Quick Views: Rahmenvorschau an/aus',
          'menu.frame.status' => 'Zeigt den Bildausschnitt des aktiven Presets im Viewport.',
          'menu.reload' => 'Neu laden (Entwicklung)',
          'dialog.title' => 'Quick Views – Szenen exportieren',
          'overlay.name' => 'Quick Views Rahmen',
          'overlay.description' => 'Zeigt den Bildausschnitt des aktiven Quick-Views-Presets.',
          'preset.new' => 'Neues Preset',
          'preset.rename' => 'Preset umbenennen',
          'preset.copy' => '%{name} (Kopie)',
          'preset.delete_confirm' => 'Preset „%{name}“ löschen?',
          'preset.name' => 'Name',
          'preset.untitled' => 'Ohne Namen',
          'preset.builtin_readonly' => 'Eingebaute Presets können nicht geändert werden.',
          'preset.builtin_undeletable' => 'Eingebaute Presets können nicht gelöscht werden.',
          'preset.not_found' => 'Preset nicht gefunden oder nicht umbenennbar.',
          'preset.viewport' => 'Viewport (aktuelle Fenstergröße)',
          'preset.a4_landscape' => 'A4 quer, 300 dpi',
          'preset.a4_portrait' => 'A4 hoch, 300 dpi',
          'preset.a3_landscape' => 'A3 quer, 300 dpi',
          'preset.square' => 'Quadrat',
          'dir.choose' => 'Ausgabeordner wählen',
          'dir.remember' => 'Quick Views: Ausgabeordner merken',
          'model.untitled' => 'Unbenannt',
          'scene.default' => 'Szene',
          'error.running' => 'Ein Export läuft bereits.',
          'error.no_scenes' => 'Keine Szenen ausgewählt.',
          'error.no_dir' => 'Bitte einen Ausgabeordner wählen.',
          'error.dir_not_writable' => 'Ordner nicht beschreibbar: %{dir}',
          'error.write_failed' => 'write_image ist fehlgeschlagen (Auflösung für die Grafikkarte zu hoch?)',
          'reloaded' => 'Quick Views %{version} neu geladen (%{count} Dateien).',
        },
      }.freeze

      def self.lang
        @lang ||= Sketchup.get_locale.to_s.downcase.start_with?('de') ? 'de' : 'en'
      end

      # For tests and for trying the other language from the Ruby console.
      def self.lang=(value)
        @lang = value.to_s == 'de' ? 'de' : 'en'
      end

      def self.t(key, vars = {})
        text = STRINGS[lang][key] || STRINGS['en'][key] || key
        vars.reduce(text) { |s, (k, v)| s.gsub("%{#{k}}", v.to_s) }
      end
    end
  end
end
