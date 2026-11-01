# Quick Views spike: measures which part of the viewport View#write_image exports
# when the image aspect ratio differs from the viewport aspect ratio.
#
# Usage (Ruby console):  load "/path/to/spike/frame_spike.rb"
# Or headless:           SketchUp -RubyStartup /path/to/spike/frame_spike.rb
#
# The script places coloured marker squares at known viewport positions,
# exports several image sizes (native and with Quick Views' fov compensation)
# and writes spike/out/results.json. spike/analyze.py then finds the
# markers in the PNGs and compares them to the predicted positions.

require 'json'
require 'fileutils'

module QuickViewsSpike
  OUT = File.join(__dir__, 'out')

  MARKERS = {
    'magenta' => [[0.30, 0.30], [255, 0, 255]],
    'cyan'    => [[0.70, 0.65], [0, 255, 255]],
    'yellow'  => [[0.50, 0.50], [255, 255, 0]],
  }.freeze

  # name => [width, height]
  SIZES = {
    'wide_16x9'   => [1600, 900],
    'a4_portrait' => [707, 1000],
    'square'      => [1000, 1000],
  }.freeze

  def self.run(quit_after: false)
    FileUtils.mkdir_p(OUT)
    model = Sketchup.active_model
    view = model.active_view
    results = {
      'sketchup' => Sketchup.version,
      'vp' => [view.vpwidth, view.vpheight],
      'ui_scale' => (UI.respond_to?(:scale_factor) ? UI.scale_factor : nil),
      'cases' => [],
    }
    model.start_operation('Quick Views spike', true)
    setup_rendering(model)
    [true, false].each do |persp|
      set_camera(view, persp)
      group = add_markers(model, view)
      vp = [view.vpwidth.to_f, view.vpheight.to_f]
      SIZES.each do |name, (w, h)|
        cam_id = persp ? 'persp' : 'ortho'
        # 1) native: plain write_image
        results['cases'] << export_case(view, "#{cam_id}_#{name}_native", w, h, group, vp, 'native')
        # 2) compensated: camera shrunk so the image equals the frame inscribed
        #    in the viewport (what the Quick Views overlay draws)
        original = copy_camera(view.camera)
        view.camera = compensated_camera(view.camera, vp[0] / vp[1], w.to_f / h)
        results['cases'] << export_case(view, "#{cam_id}_#{name}_comp", w, h, group, vp, 'inscribed',
                                        screen_view_camera: original)
        view.camera = original
      end
      if persp
        # 3) scene camera with a fixed aspect ratio (Camera#aspect_ratio)
        cam = view.camera
        cam.aspect_ratio = 1.5
        view.camera = cam
        group.erase!
        group = add_markers(model, view)
        SIZES.each do |name, (w, h)|
          results['cases'] << export_case(view, "persp_ar15_#{name}_native", w, h, group, vp, 'native',
                                          aspect_ratio: 1.5)
        end
        cam = view.camera
        cam.aspect_ratio = 0.0
        view.camera = cam
      end
      group.erase!
    end
    File.write(File.join(OUT, 'results.json'), JSON.pretty_generate(results))
    model.abort_operation
    puts "Quick Views spike done: #{OUT}"
    Sketchup.quit if quit_after
  rescue StandardError => e
    File.write(File.join(OUT, 'error.txt'), "#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
    model&.abort_operation
    Sketchup.quit if quit_after
  end

  def self.setup_rendering(model)
    ro = model.rendering_options
    {
      'BackgroundColor' => Sketchup::Color.new(255, 255, 255),
      'DrawGround' => false, 'DrawHorizon' => false, 'DrawSilhouettes' => false,
      'DisplayFog' => false, 'DrawDepthQue' => false, 'ExtendLines' => false,
      'EdgeDisplayMode' => 0, 'DisplaySketchAxes' => false,
    }.each do |k, v|
      begin
        ro[k] = v
      rescue StandardError
        nil
      end
    end
    si = model.shadow_info
    si['DisplayShadows'] = false
    si['Light'] = 0
    si['Dark'] = 100
  end

  def self.set_camera(view, persp)
    cam = Sketchup::Camera.new([0, -2000, 500], [0, 0, 500], [0, 0, 1])
    cam.perspective = persp
    if persp
      cam.fov = 35.0
    else
      cam.height = 800.0
    end
    view.camera = cam
  end

  def self.copy_camera(cam)
    c = Sketchup::Camera.new(cam.eye, cam.target, cam.up, cam.perspective?)
    if cam.perspective?
      c.fov = cam.fov
    else
      c.height = cam.height
    end
    c.aspect_ratio = cam.aspect_ratio
    c
  end

  # Hypothesis: write_image keeps the vertical extent (fov/height) and
  # crops/extends horizontally. If the image is wider than the viewport the
  # vertical extent is reduced so the full viewport width maps to the image.
  def self.compensated_camera(cam, vp_aspect, img_aspect)
    c = copy_camera(cam)
    return c if img_aspect <= vp_aspect

    k = vp_aspect / img_aspect
    if c.perspective?
      half = Math.atan(Math.tan(c.fov.degrees / 2.0) * k)
      c.fov = (half * 2.0).radians
    else
      c.height = c.height * k
    end
    c
  end

  def self.add_markers(model, view)
    group = model.entities.add_group
    vw = view.vpwidth.to_f
    vh = view.vpheight.to_f
    size = vh * 0.03
    plane = [[0, 0, 0], [0, 1, 0]]
    MARKERS.each do |name, ((fx, fy), rgb)|
      mat = model.materials[name] || model.materials.add(name)
      mat.color = Sketchup::Color.new(*rgb)
      corners = [[-1, -1], [1, -1], [1, 1], [-1, 1]].map do |dx, dy|
        ray = view.pickray(fx * vw + dx * size / 2, fy * vh + dy * size / 2)
        Geom.intersect_line_plane(ray, plane)
      end
      face = group.entities.add_face(corners)
      face.material = mat
      face.back_material = mat
    end
    group
  end

  def self.export_case(view, id, w, h, group, vp, hypothesis, screen_view_camera: nil, aspect_ratio: 0.0)
    path = File.join(OUT, "#{id}.png")
    # Marker positions are measured with the camera the user sees (before
    # compensation), so the prediction refers to the visible viewport.
    current = view.camera
    view.camera = screen_view_camera if screen_view_camera
    markers = {}
    MARKERS.each_key do |name|
      face = group.entities.grep(Sketchup::Face).find { |f| f.material&.name == name }
      center = face.bounds.center
      sc = view.screen_coords(center)
      markers[name] = [sc.x.to_f, sc.y.to_f]
    end
    view.camera = current if screen_view_camera
    ok = view.write_image(filename: path, width: w, height: h, antialias: false, transparent: false)
    {
      'id' => id, 'file' => File.basename(path), 'ok' => ok, 'size' => [w, h], 'vp' => vp,
      'hypothesis' => hypothesis, 'markers_vp' => markers,
      'perspective' => view.camera.perspective?, 'fov_is_height' => view.camera.fov_is_height?,
      'aspect_ratio' => aspect_ratio,
    }
  end
end

autoquit = !ENV['QUICKVIEWS_SPIKE_AUTOQUIT'].nil?
UI.start_timer(autoquit ? 8 : 0, false) { QuickViewsSpike.run(quit_after: autoquit) }
