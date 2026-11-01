module JG
  module QuickViews
    # Exports scenes one by one via UI.start_timer, so the dialog stays
    # responsive (progress, cancel). Nothing is written to the undo stack:
    # the exporter only selects scenes and narrows the live camera, and
    # restores scene, camera, tag visibility, style and transition settings
    # afterwards.
    class Exporter
      STEP_DELAY = 0.05 # seconds between timer ticks

      # listener must respond to #export_progress(done, total, scene_name)
      # and #export_finished(summary_hash).
      def initialize(model, pages:, preset:, pattern:, directory:, existing:, listener:)
        @model = model
        @view = model.active_view
        @pages = pages
        @preset = preset
        @pattern = pattern
        @directory = directory
        @existing = existing == 'overwrite' ? :overwrite : :suffix
        @listener = listener
        @cancelled = false
        @running = false
      end

      def running?
        @running
      end

      def cancel
        @cancelled = true
      end

      def start
        raise ArgumentError, L10n.t('error.no_scenes') if @pages.empty?
        unless File.directory?(@directory) && File.writable?(@directory)
          raise ArgumentError, L10n.t('error.dir_not_writable', dir: @directory)
        end

        @running = true
        @started = Time.now
        @width, @height = Presets.size_for(@preset, @view)
        @extension = @preset['format']
        @allocator = FilenamePattern::Allocator.new(@directory, @extension, existing: @existing)
        @results = []
        @index = 0
        save_state
        page_options['ShowTransition'] = false
        FrameOverlay.suspend if defined?(FrameOverlay)
        schedule { select_scene }
      rescue StandardError
        @running = false
        raise
      end

      private

      def schedule(&block)
        UI.start_timer(STEP_DELAY, false) do
          begin
            block.call
          rescue StandardError => e
            # Unexpected failure outside a single scene: stop cleanly.
            @results << { 'scene' => current_page&.name.to_s, 'ok' => false, 'error' => "#{e.class}: #{e.message}" }
            finish
          end
        end
      end

      def current_page
        @pages[@index]
      end

      # Tick 1: activate the scene (style, tags, camera …) without transition.
      def select_scene
        return finish if @cancelled || @index >= @pages.size

        page = current_page
        @listener.export_progress(@index, @pages.size, page.name)
        begin
          @model.pages.selected_page = page
        rescue StandardError => e
          record_error(page, e)
          return next_scene
        end
        schedule { export_scene }
      end

      # Tick 2: render the image.
      def export_scene
        page = current_page
        path = nil
        begin
          base = FilenamePattern.render(@pattern, context_for(page))
          path = @allocator.allocate(base)
          restore_camera = fit_camera
          ok = begin
            @view.write_image(image_options(path))
          ensure
            restore_camera.call
          end
          raise L10n.t('error.write_failed') unless ok

          @results << { 'scene' => page.name, 'ok' => true, 'file' => path }
        rescue StandardError => e
          record_error(page, e, path)
        end
        next_scene
      end

      def next_scene
        @index += 1
        schedule { select_scene }
      end

      def record_error(page, error, path = nil)
        @results << { 'scene' => page.name, 'ok' => false, 'file' => path, 'error' => error.message }
      end

      def fit_camera
        camera = @view.camera
        rect = FrameMath.visible_rect(@view.vpwidth, @view.vpheight, camera.aspect_ratio)
        view_aspect = rect[2] / rect[3]
        restore = FrameMath.fit_camera!(camera, view_aspect, @width.to_f / @height)
        @view.camera = camera
        lambda do
          restore.call
          @view.camera = camera
        end
      end

      def image_options(path)
        opts = {
          filename: path,
          width: @width,
          height: @height,
          antialias: @preset['antialias'],
          scale_factor: @preset['line_scale'].to_f,
        }
        if @extension == 'jpg'
          # ASSUMPTION: compression 1.0 = best quality (like the slider in
          # SketchUp's export dialog). See README "Known limitations".
          opts[:compression] = @preset['jpg_quality'].to_i / 100.0
        else
          opts[:transparent] = @preset['transparent']
        end
        opts
      end

      def context_for(page)
        {
          nr: @model.pages.to_a.index(page).to_i + 1,
          scene: page.name,
          model: model_name,
          time: @started,
          preset: @preset['name'],
          width: @width,
          height: @height,
        }
      end

      def model_name
        name = @model.title.to_s
        name.empty? ? L10n.t('model.untitled') : name
      end

      def finish
        return unless @running

        @running = false
        restore_state
        ok = @results.count { |r| r['ok'] }
        @listener.export_finished(
          'cancelled' => @cancelled,
          'total' => @pages.size,
          'processed' => @results.size,
          'ok' => ok,
          'directory' => @directory,
          'results' => @results,
          'seconds' => (Time.now - @started).round(1)
        )
      end

      def page_options
        @model.options['PageOptions']
      end

      def save_state
        @state = {
          page: @model.pages.selected_page,
          camera: FrameMath.copy_camera(@view.camera),
          show_transition: page_options['ShowTransition'],
          style: @model.styles.selected_style,
          layers: @model.layers.map { |layer| [layer, layer.visible?] },
        }
      end

      def restore_state
        s = @state
        begin
          @model.pages.selected_page = s[:page] if s[:page]&.valid?
          @model.styles.selected_style = s[:style] if s[:style]&.valid? && @model.styles.selected_style != s[:style]
          # Only touch tags that differ, to keep the undo stack clean.
          s[:layers].each do |layer, visible|
            layer.visible = visible if layer.valid? && layer.visible? != visible
          end
          @view.camera = s[:camera]
        ensure
          page_options['ShowTransition'] = s[:show_transition]
          FrameOverlay.resume if defined?(FrameOverlay)
          @view.invalidate
        end
      end
    end
  end
end
