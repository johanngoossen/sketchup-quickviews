require 'json'

module JG
  module QuickViews
    # The Quick Views HtmlDialog: presets, file name pattern, scene selection,
    # output folder, export with progress and cancel.
    module Dialog
      ATTR_DICT = 'QuickViews'.freeze
      LEGACY_ATTR_DICT = 'JViews'.freeze # folder remembered by the development version

      @dialog = nil
      @exporter = nil

      class << self
        def show
          if @dialog&.visible?
            @dialog.bring_to_front
            return
          end
          @dialog = create_dialog
          @dialog.show
        end

        def close
          @dialog&.close
          @dialog = nil
        end

        # Called when another model becomes active.
        def refresh_model
          send_state if @dialog&.visible?
        end

        # --- exporter listener -------------------------------------------

        def export_progress(done, total, scene)
          call_js('progress', 'done' => done, 'total' => total, 'scene' => scene)
        end

        def export_finished(summary)
          @exporter = nil
          call_js('finished', summary)
        end

        private

        def create_dialog
          dlg = UI::HtmlDialog.new(
            dialog_title: L10n.t('dialog.title'),
            preferences_key: 'QuickViews.dialog',
            scrollable: true,
            resizable: true,
            width: 560,
            height: 820,
            min_width: 460,
            min_height: 520,
            style: UI::HtmlDialog::STYLE_DIALOG
          )
          dlg.set_file(File.join(PLUGIN_DIR, 'ui', 'dialog.html'))
          register_callbacks(dlg)
          dlg.set_on_closed do
            @exporter&.cancel
            @dialog = nil
          end
          dlg
        end

        def register_callbacks(dlg)
          {
            'ready' => :on_ready,
            'selectPreset' => :on_select_preset,
            'formChanged' => :on_form_changed,
            'savePreset' => :on_save_preset,
            'saveAsPreset' => :on_save_as_preset,
            'renamePreset' => :on_rename_preset,
            'deletePreset' => :on_delete_preset,
            'preview' => :on_preview,
            'chooseDir' => :on_choose_dir,
            'start' => :on_start,
            'cancel' => :on_cancel,
            'openFolder' => :on_open_folder,
            'toggleFrame' => :on_toggle_frame,
            'frameOpacity' => :on_frame_opacity,
            'openUrl' => :on_open_url,
          }.each do |name, handler|
            dlg.add_action_callback(name) do |_ctx, json|
              begin
                data = json.to_s.empty? ? {} : JSON.parse(json)
                Dialog.send(handler, data)
              rescue StandardError => e
                Dialog.send(:call_js, 'error', 'message' => e.message)
                puts "#{NAME}: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
              end
            end
          end
        end

        def call_js(fn, payload)
          return unless @dialog

          @dialog.execute_script("JV.#{fn}(#{JSON.generate(payload)})")
        end

        # --- callbacks ---------------------------------------------------

        def on_ready(_data)
          send_state
        end

        def on_select_preset(data)
          preset = Presets.find(data['id'].to_s)
          return unless preset

          Presets.active_id = preset['id']
          update_frame(preset)
        end

        # Unsaved form values drive the frame preview too.
        def on_form_changed(data)
          update_frame(Presets.normalize(data['settings'] || {}))
        end

        def on_save_preset(data)
          preset = Presets.save(data['settings'])
          Presets.active_id = preset['id']
          send_presets
        end

        def on_save_as_preset(data)
          settings = data['settings'] || {}
          name = ask_name(L10n.t('preset.new'), L10n.t('preset.copy', name: settings['name']))
          return unless name

          preset = Presets.duplicate(settings, name)
          Presets.active_id = preset['id']
          send_presets
        end

        def on_rename_preset(data)
          preset = Presets.find(data['id'].to_s)
          return unless preset

          name = ask_name(L10n.t('preset.rename'), preset['name'])
          return unless name

          Presets.rename(preset['id'], name)
          send_presets
        end

        def on_delete_preset(data)
          preset = Presets.find(data['id'].to_s)
          return unless preset

          answer = UI.messagebox(L10n.t('preset.delete_confirm', name: preset['name']), MB_YESNO)
          return unless answer == IDYES

          Presets.delete(preset['id'])
          Presets.active_id = 'full_hd' if Presets.active_id == preset['id']
          send_presets
        end

        def on_preview(data)
          Sketchup.write_default(PREFS, 'pattern', data['pattern'].to_s)
          model = Sketchup.active_model
          settings = Presets.normalize(data['settings'] || {})
          pages = model.pages.to_a
          index = data['sceneIndex'].to_i
          page = pages[index] || pages.first
          w, h = Presets.size_for(settings, model.active_view)
          name = FilenamePattern.render(
            data['pattern'], nr: page ? index + 1 : 1, scene: page ? page.name : L10n.t('scene.default'),
                             model: model_name(model),
                             time: Time.now, preset: settings['name'], width: w, height: h
          )
          call_js('preview', 'text' => "#{name}.#{settings['format']}")
        end

        def on_choose_dir(_data)
          model = Sketchup.active_model
          dir = UI.select_directory(title: L10n.t('dir.choose'), directory: last_dir(model))
          return unless dir

          remember_dir(model, dir)
          call_js('dir', 'path' => dir)
        end

        def on_start(data)
          raise L10n.t('error.running') if @exporter&.running?

          model = Sketchup.active_model
          pages = model.pages.to_a
          selected = Array(data['scenes']).map(&:to_i).uniq.sort.map { |i| pages[i] }.compact
          raise L10n.t('error.no_scenes') if selected.empty?

          dir = data['directory'].to_s
          dir = last_dir(model) if dir.empty?
          raise L10n.t('error.no_dir') if dir.to_s.empty?

          remember_dir(model, dir)
          existing = data['existing'] == 'overwrite' ? 'overwrite' : 'suffix'
          Sketchup.write_default(PREFS, 'existing', existing)
          Sketchup.write_default(PREFS, 'pattern', data['pattern'].to_s)
          @exporter = Exporter.new(
            model,
            pages: selected,
            preset: Presets.normalize(data['settings'] || {}),
            pattern: data['pattern'].to_s,
            directory: dir,
            existing: existing,
            listener: self
          )
          @exporter.start
        rescue StandardError
          @exporter = nil
          raise
        end

        def on_cancel(_data)
          @exporter&.cancel
        end

        def on_open_folder(data)
          dir = data['path'].to_s
          return unless File.directory?(dir)

          if Sketchup.platform == :platform_osx
            system('open', dir)
          else
            UI.openURL("file:///#{dir.tr('\\', '/')}")
          end
        end

        def on_toggle_frame(data)
          FrameOverlay.enabled = data.key?('enabled') ? data['enabled'] : !FrameOverlay.enabled?
          call_js('frameState', frame_state)
        end

        # Only the credit link; other URLs are ignored.
        def on_open_url(data)
          url = data['url'].to_s
          UI.openURL(url) if url.start_with?('https://johanngoossen.com')
        end

        def on_frame_opacity(data)
          FrameOverlay.opacity = data['opacity']
        end

        def frame_state
          { 'enabled' => FrameOverlay.enabled?, 'supported' => FrameOverlay.supported?, 'opacity' => FrameOverlay.opacity }
        end

        # --- helpers -----------------------------------------------------

        def send_state
          model = Sketchup.active_model
          view = model.active_view
          call_js('state',
                  'presets' => Presets.all,
                  'activePresetId' => Presets.active_id,
                  'scenes' => scenes(model),
                  'pattern' => Sketchup.read_default(PREFS, 'pattern', FilenamePattern.default_pattern).to_s,
                  'existing' => Sketchup.read_default(PREFS, 'existing', 'suffix').to_s,
                  'directory' => last_dir(model).to_s,
                  'model' => model_name(model),
                  'viewport' => [view.vpwidth, view.vpheight],
                  'frame' => frame_state,
                  'version' => VERSION,
                  'lang' => L10n.lang)
          update_frame(Presets.find(Presets.active_id))
        end

        def send_presets
          call_js('presets', 'presets' => Presets.all, 'activePresetId' => Presets.active_id)
          update_frame(Presets.find(Presets.active_id))
        end

        def scenes(model)
          model.pages.to_a.each_with_index.map do |page, i|
            anim = page.respond_to?(:include_in_animation?) ? page.include_in_animation? : true
            { 'index' => i, 'name' => page.name, 'animation' => anim }
          end
        end

        def update_frame(preset)
          return unless preset

          w, h = Presets.size_for(preset)
          FrameOverlay.set_target(width: w, height: h, label: preset['name'], viewport: preset['viewport'])
        end

        def ask_name(title, default)
          result = UI.inputbox([L10n.t('preset.name')], [default.to_s], title)
          return nil unless result

          name = result.first.to_s.strip
          name.empty? ? nil : name
        end

        def model_name(model)
          name = model.title.to_s
          name.empty? ? L10n.t('model.untitled') : name
        end

        # Last folder: per model (attribute), else global, else model folder.
        def last_dir(model)
          dir = (model.get_attribute(ATTR_DICT, 'last_dir') || model.get_attribute(LEGACY_ATTR_DICT, 'last_dir')).to_s
          dir = Sketchup.read_default(PREFS, 'last_dir', '').to_s unless File.directory?(dir)
          dir = File.dirname(model.path) if !File.directory?(dir) && !model.path.to_s.empty?
          File.directory?(dir) ? dir : ''
        end

        def remember_dir(model, dir)
          Sketchup.write_default(PREFS, 'last_dir', dir)
          return if model.get_attribute(ATTR_DICT, 'last_dir') == dir

          # Transparent operation: merges into the previous undo step instead
          # of adding an own entry. The model is marked as modified.
          model.start_operation(L10n.t('dir.remember'), true, false, true)
          model.set_attribute(ATTR_DICT, 'last_dir', dir)
          model.commit_operation
        end
      end
    end
  end
end
