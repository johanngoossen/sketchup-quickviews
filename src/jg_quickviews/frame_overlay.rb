module JG
  module QuickViews
    # Viewport frame preview: shows the aspect ratio of the active preset and
    # greys out what the export will not contain. Uses Sketchup::Overlay
    # (SketchUp 2023+), so it stays visible while orbiting and never touches
    # the model.
    module FrameOverlay
      OVERLAY_ID = 'jg_quickviews.frame'.freeze
      SHADE_RGB = [40, 40, 40].freeze
      OPACITY_KEY = 'frame_opacity'.freeze
      DEFAULT_OPACITY = 55 # percent
      INK = Sketchup::Color.new(0, 0, 0) # frame line and label

      # ||= keeps the state across QuickViews.reload
      @enabled ||= false
      @suspended ||= false
      @target ||= { width: 1920, height: 1080, label: 'Full HD', viewport: false }

      class << self
        attr_reader :target

        def supported?
          defined?(Sketchup::Overlay) ? true : false
        end

        def enabled?
          @enabled
        end

        def toggle
          self.enabled = !@enabled
        end

        def enabled=(value)
          @enabled = value ? true : false
          apply_to(Sketchup.active_model)
        end

        # Sets what the frame shows; called on preset or form changes.
        def set_target(width:, height:, label:, viewport: false)
          @target = { width: width.to_i, height: height.to_i, label: label.to_s, viewport: viewport }
          invalidate
        end

        # Opacity of the grey cover outside the frame, 0..100 %, stored globally.
        def opacity
          @opacity ||= Sketchup.read_default(PREFS, OPACITY_KEY, DEFAULT_OPACITY).to_i.clamp(0, 100)
        end

        def opacity=(percent)
          @opacity = percent.to_i.clamp(0, 100)
          Sketchup.write_default(PREFS, OPACITY_KEY, @opacity)
          invalidate
        end

        # Hidden while the exporter changes the camera.
        def suspend
          @suspended = true
          apply_to(Sketchup.active_model)
        end

        def resume
          @suspended = false
          apply_to(Sketchup.active_model)
        end

        # Makes sure the model has our overlay and its state matches.
        def apply_to(model)
          return unless supported? && model

          overlay = overlay_for(model)
          overlay.enabled = @enabled && !@suspended if overlay
          model.active_view.invalidate
        end

        def overlay_for(model)
          model.overlays.each do |o|
            return o if o.respond_to?(:overlay_id) && o.overlay_id == OVERLAY_ID
          end

          overlay = Overlay.new
          model.overlays.add(overlay)
          overlay
        end

        def invalidate
          Sketchup.active_model&.active_view&.invalidate
        end

        # The drawing itself; kept here so a reload updates existing overlays.
        def draw(view)
          t = @target
          cam = view.camera
          visible = FrameMath.visible_rect(view.vpwidth, view.vpheight, cam.aspect_ratio)
          frame = if t[:viewport] || t[:width] <= 0 || t[:height] <= 0
                    visible
                  else
                    FrameMath.frame_rect(view.vpwidth, view.vpheight, t[:width], t[:height], cam.aspect_ratio)
                  end
          draw_shade(view, visible, frame)
          draw_border(view, frame)
          draw_label(view, frame, t)
        end

        private

        def draw_shade(view, outer, inner)
          ox, oy, ow, oh = outer
          ix, iy, iw, ih = inner
          quads = []
          add_rect(quads, ox, oy, ow, iy - oy)                       # top
          add_rect(quads, ox, iy + ih, ow, (oy + oh) - (iy + ih))    # bottom
          add_rect(quads, ox, iy, ix - ox, ih)                       # left
          add_rect(quads, ix + iw, iy, (ox + ow) - (ix + iw), ih)    # right
          alpha = (opacity * 2.55).round
          return if quads.empty? || alpha.zero?

          view.drawing_color = Sketchup::Color.new(*SHADE_RGB, alpha)
          view.draw2d(GL_QUADS, quads)
        end

        def add_rect(quads, x, y, w, h)
          return if w < 0.5 || h < 0.5

          quads.push(Geom::Point3d.new(x, y, 0), Geom::Point3d.new(x + w, y, 0),
                     Geom::Point3d.new(x + w, y + h, 0), Geom::Point3d.new(x, y + h, 0))
        end

        def draw_border(view, rect)
          x, y, w, h = rect
          view.line_width = 1.5
          view.line_stipple = ''
          view.drawing_color = INK
          pts = [[x, y], [x + w, y], [x + w, y + h], [x, y + h]].map { |px, py| Geom::Point3d.new(px, py, 0) }
          view.draw2d(GL_LINE_LOOP, pts)
        end

        def draw_label(view, rect, t)
          x, y, = rect
          size = t[:viewport] ? "#{view.vpwidth} × #{view.vpheight}" : "#{t[:width]} × #{t[:height]}"
          text = "#{NAME} · #{t[:label]} · #{size} px"
          view.draw_text(Geom::Point3d.new(x + 8, y + 6, 0), text, size: 11, color: INK)
        rescue ArgumentError
          view.draw_text(Geom::Point3d.new(x + 8, y + 6, 0), text)
        end
      end

      if defined?(Sketchup::Overlay)
        class Overlay < Sketchup::Overlay
          def initialize
            super(OVERLAY_ID, L10n.t('overlay.name'), description: L10n.t('overlay.description'))
          end

          def draw(view)
            FrameOverlay.draw(view)
          end
        end

        # Attaches the overlay to new, opened and activated models.
        class AppObserver < Sketchup::AppObserver
          # Also notify about the model SketchUp opens at startup.
          def expectsStartupModelNotifications
            true
          end

          def onNewModel(model)
            FrameOverlay.apply_to(model)
          end

          def onOpenModel(model)
            FrameOverlay.apply_to(model)
          end

          def onActivateModel(model)
            FrameOverlay.apply_to(model)
            Dialog.refresh_model if defined?(Dialog)
          end
        end
      end
    end
  end
end
