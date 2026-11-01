module JG
  module QuickViews
    # Turns a pattern like "{nr}_{scene}" into safe, unique file names.
    # Placeholders exist in English and German; both work in either language.
    module FilenamePattern
      PLACEHOLDERS = {
        'en' => %w[nr scene model date time preset width height],
        'de' => %w[nr szene modell datum zeit preset breite hoehe],
      }.freeze
      INVALID_CHARS = %r{[/\\:*?"<>|\x00-\x1F]}.freeze

      def self.default_pattern(lang = L10n.lang)
        "{nr}_{#{PLACEHOLDERS.fetch(lang, PLACEHOLDERS['en'])[1]}}"
      end

      # context keys: :nr (1-based scene position), :scene, :model, :time,
      # :preset, :width, :height
      def self.render(pattern, context)
        time = context[:time] || Time.now
        values = [
          format('%02d', context[:nr].to_i),
          context[:scene].to_s,
          context[:model].to_s,
          time.strftime('%y%m%d'), # YYMMDD, e.g. 261101
          time.strftime('%H%M'),
          context[:preset].to_s,
          context[:width].to_s,
          context[:height].to_s,
        ]
        lookup = {}
        PLACEHOLDERS.each_value { |names| names.zip(values) { |n, v| lookup[n] = v } }
        pattern = default_pattern if pattern.to_s.strip.empty?
        name = pattern.to_s.gsub(/\{(\w+)\}/) { lookup.fetch(Regexp.last_match(1).downcase, Regexp.last_match(0)) }
        sanitize(name)
      end

      # Replaces characters not allowed on macOS/Windows, keeps spaces.
      def self.sanitize(name)
        clean = name.to_s.gsub(INVALID_CHARS, '_').strip
        clean = clean.sub(/[. ]+\z/, '') # Windows rejects trailing dots/spaces
        clean = clean.sub(/\A\.+/, '')   # no hidden files
        clean.empty? ? L10n.t('scene.default') : clean
      end

      # Keeps track of names used in one export run and resolves collisions.
      class Allocator
        # existing: :overwrite | :suffix (behaviour for files already on disk)
        def initialize(directory, extension, existing: :suffix)
          @directory = directory
          @extension = extension
          @existing = existing
          @used = {}
        end

        # Returns the full path for a base name, adding _2, _3 … where needed.
        def allocate(base)
          candidate = base
          n = 1
          while taken?(candidate)
            n += 1
            candidate = "#{base}_#{n}"
          end
          @used[candidate.downcase] = true
          path_for(candidate)
        end

        private

        # Names are compared case-insensitively (macOS/Windows file systems).
        def taken?(name)
          return true if @used[name.downcase]

          @existing == :suffix && File.exist?(path_for(name))
        end

        def path_for(name)
          File.join(@directory, "#{name}.#{@extension}")
        end
      end
    end
  end
end
