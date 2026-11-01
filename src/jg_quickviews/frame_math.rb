module JG
  module QuickViews
    # Geometry shared by the viewport overlay and the exporter, so the frame
    # drawn in the viewport and the exported image use the same model.
    #
    # Model (see spike/ and README "Rahmen"):
    # * write_image keeps the camera's locked extent: the vertical extent
    #   when camera.fov_is_height? (SketchUp default, also orthographic
    #   camera.height), otherwise the horizontal extent. The other direction
    #   is cropped or extended to match the image aspect ratio.
    # * Quick Views always exports the largest rectangle with the image aspect
    #   ratio that fits centred into the visible viewport ("inscribed frame").
    #   Where write_image would show more than the viewport, the export
    #   camera's fov/height is reduced accordingly (on a temporary camera,
    #   the scene camera is never changed).
    module FrameMath
      # Visible part of the viewport. A camera with a fixed aspect ratio
      # (Camera#aspect_ratio > 0) shows grey bars; only the inner part counts.
      # Returns [x, y, w, h] in view coordinates.
      def self.visible_rect(vp_w, vp_h, camera_aspect = 0.0)
        vp_w = vp_w.to_f
        vp_h = vp_h.to_f
        return [0.0, 0.0, vp_w, vp_h] if camera_aspect.to_f <= 0.0

        inscribe([0.0, 0.0, vp_w, vp_h], camera_aspect.to_f)
      end

      # Largest centred rectangle with the given aspect ratio inside rect.
      def self.inscribe(rect, aspect)
        x, y, w, h = rect
        if aspect > w / h
          fh = w / aspect
          [x, y + (h - fh) / 2.0, w, fh]
        else
          fw = h * aspect
          [x + (w - fw) / 2.0, y, fw, h]
        end
      end

      # Frame rectangle of an image size inside the viewport.
      def self.frame_rect(vp_w, vp_h, img_w, img_h, camera_aspect = 0.0)
        inscribe(visible_rect(vp_w, vp_h, camera_aspect), img_w.to_f / img_h)
      end

      # Factor (<= 1) by which the locked extent must shrink so the export
      # matches the inscribed frame. 1.0 means no change.
      def self.shrink_factor(view_aspect, img_aspect, fov_is_height)
        if fov_is_height
          img_aspect > view_aspect ? view_aspect / img_aspect : 1.0
        else
          img_aspect < view_aspect ? img_aspect / view_aspect : 1.0
        end
      end

      # Narrows the camera in place so the export matches the inscribed frame.
      # Works on view.camera directly (keeps 2D pan/zoom of two-point
      # perspective). Returns a proc that restores the previous values.
      def self.fit_camera!(camera, view_aspect, img_aspect)
        k = shrink_factor(view_aspect, img_aspect, camera.fov_is_height?)
        return -> {} if (k - 1.0).abs < 1e-9

        if camera.perspective?
          fov = camera.fov
          half = Math.atan(Math.tan(fov.degrees / 2.0) * k)
          camera.fov = (half * 2.0).radians
          -> { camera.fov = fov }
        else
          height = camera.height
          camera.height = height * k
          -> { camera.height = height }
        end
      end

      # Independent copy for restoring the user's view after an export.
      # Note: the 2D pan/zoom of two-point perspective is not copied (API
      # offers no setter).
      def self.copy_camera(camera)
        cam = Sketchup::Camera.new(camera.eye, camera.target, camera.up, camera.perspective?)
        if camera.perspective?
          cam.fov = camera.fov
        else
          cam.height = camera.height
        end
        cam.aspect_ratio = camera.aspect_ratio
        cam
      end
    end
  end
end
