require 'json'

module JG
  module QuickViews
    # Export presets. Built-in presets are fixed; user presets are stored
    # globally (all models) as JSON via Sketchup.write_default.
    module Presets
      PREFS_SECTION = 'QuickViews'.freeze
      PREFS_KEY = 'presets'.freeze
      ACTIVE_KEY = 'active_preset'.freeze
      VIEWPORT_ID = 'viewport'.freeze

      DEFAULTS = {
        'format' => 'png',      # 'png' | 'jpg'
        'jpg_quality' => 90,    # 0..100, only jpg
        'antialias' => true,
        'transparent' => false, # only png
        'line_scale' => 1.0,    # write_image :scale_factor (line width / text)
      }.freeze

      # Names of viewport, A4/A3 and square come from L10n ("preset.<id>").
      BUILTIN = [
        ['viewport', 'Viewport', nil, nil],
        ['hd', 'HD', 1280, 720],
        ['full_hd', 'Full HD', 1920, 1080],
        ['uhd_4k', '4K UHD', 3840, 2160],
        ['a4_landscape', 'A4 landscape', 3508, 2480],
        ['a4_portrait', 'A4 portrait', 2480, 3508],
        ['a3_landscape', 'A3 landscape', 4961, 3508],
        ['square', 'Square', 2048, 2048],
        ['social_4x5', 'Social 4:5', 1080, 1350],
        ['social_story', 'Social Story 9:16', 1080, 1920],
      ].map do |id, name, w, h|
        DEFAULTS.merge('id' => id, 'name' => name, 'width' => w, 'height' => h,
                       'builtin' => true, 'viewport' => id == VIEWPORT_ID).freeze
      end.freeze

      def self.all
        BUILTIN.map { |p| p.merge('name' => builtin_name(p)) } + user_presets
      end

      def self.builtin_name(preset)
        key = "preset.#{preset['id']}"
        L10n::STRINGS['en'].key?(key) ? L10n.t(key) : preset['name']
      end

      def self.find(id)
        all.find { |p| p['id'] == id }
      end

      def self.user_presets
        raw = Sketchup.read_default(PREFS_SECTION, PREFS_KEY, '[]')
        list = JSON.parse(raw.to_s)
        list.is_a?(Array) ? list.map { |p| normalize(p) } : []
      rescue JSON::ParserError
        []
      end

      # Creates or updates a user preset. Returns the stored preset.
      def self.save(preset)
        preset = normalize(preset)
        raise ArgumentError, L10n.t('preset.builtin_readonly') if builtin_id?(preset['id'])

        list = user_presets
        preset['id'] = new_id if preset['id'].to_s.empty?
        idx = list.index { |p| p['id'] == preset['id'] }
        idx ? list[idx] = preset : list << preset
        write(list)
        preset
      end

      # Copy of any preset (built-in or user) as a new user preset.
      def self.duplicate(preset, name)
        copy = normalize(preset).merge('id' => '', 'name' => name.to_s.strip)
        copy['name'] = L10n.t('preset.copy', name: preset['name']) if copy['name'].empty?
        save(copy)
      end

      def self.rename(id, name)
        preset = user_presets.find { |p| p['id'] == id }
        raise ArgumentError, L10n.t('preset.not_found') unless preset

        save(preset.merge('name' => name.to_s.strip))
      end

      def self.delete(id)
        raise ArgumentError, L10n.t('preset.builtin_undeletable') if builtin_id?(id)

        write(user_presets.reject { |p| p['id'] == id })
      end

      def self.active_id
        id = Sketchup.read_default(PREFS_SECTION, ACTIVE_KEY, 'full_hd').to_s
        find(id) ? id : 'full_hd'
      end

      def self.active_id=(id)
        Sketchup.write_default(PREFS_SECTION, ACTIVE_KEY, id.to_s)
      end

      def self.builtin_id?(id)
        BUILTIN.any? { |p| p['id'] == id }
      end

      # Image size of a preset; the viewport preset follows the current view.
      def self.size_for(preset, view = Sketchup.active_model&.active_view)
        if preset['viewport']
          return [view.vpwidth, view.vpheight] if view

          return [1920, 1080]
        end
        [preset['width'].to_i, preset['height'].to_i]
      end

      def self.normalize(preset)
        p = DEFAULTS.merge(preset.to_h.transform_keys(&:to_s))
        p['format'] = p['format'].to_s.downcase == 'jpg' ? 'jpg' : 'png'
        p['jpg_quality'] = p['jpg_quality'].to_i.clamp(1, 100)
        p['antialias'] = truthy(p['antialias'])
        p['transparent'] = truthy(p['transparent']) && p['format'] == 'png'
        p['line_scale'] = p['line_scale'].to_f.clamp(0.1, 20.0)
        p['viewport'] = truthy(p['viewport'])
        unless p['viewport']
          p['width'] = p['width'].to_i.clamp(1, 100_000)
          p['height'] = p['height'].to_i.clamp(1, 100_000)
        end
        p['name'] = p['name'].to_s.strip
        p['name'] = L10n.t('preset.untitled') if p['name'].empty?
        p['builtin'] = builtin_id?(p['id'])
        p
      end

      def self.truthy(value)
        value == true || %w[true 1 on yes].include?(value.to_s.downcase)
      end

      def self.new_id
        "user_#{Time.now.strftime('%Y%m%d%H%M%S')}_#{rand(1000..9999)}"
      end

      def self.write(list)
        Sketchup.write_default(PREFS_SECTION, PREFS_KEY, JSON.generate(list))
      end
      private_class_method :write, :new_id, :truthy
    end
  end
end
