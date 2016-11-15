require 'active_support/deprecation/reporting'
require 'sass'
require 'sprockets/sass_importer'
require 'tilt'

module Sass
  module Rails
    class SassImporter < Sass::Importers::Filesystem
      module Globbing
        GLOB = /(\A|\/)(\*|\*\*\/\*)\z/

        # 5.0.6
        #def find_relative(name, base, options)
          #if options[:sprockets] && m = name.match(GLOB)
            #puts "GLOBBED" if name =~ /overri/
            #path = name.sub(m[0], "")
            #base = File.expand_path(path, File.dirname(base))
            #glob_imports(base, m[2], options)
          #else
            #puts "NOTGLOBBED" if name =~ /overri/
            #super
          #end
        #end

        # 3.2.6
        def find_relative(name, base, options)
          base_pathname = Pathname.new(base)
          context = options[:sprockets][:context]

          puts "FINDING: #{name}"
          pp context
          puts context.load_path

          if name =~ GLOB
            puts "GLOBBING"
            glob_imports(name, base_pathname, options)
          elsif pathname = Pathname.new(resolve(name, base_pathname.dirname, context))
            context.depend_on(pathname)
            if sass_file?(pathname)
              Sass::Engine.new(pathname.read, options.merge(:filename => pathname.to_s, :importer => self, :syntax => syntax(pathname)))
            else
              Sass::Engine.new(@resolver.process(pathname), options.merge(:filename => pathname.to_s, :importer => self, :syntax => :scss))
            end
          else
            nil
          end
        end

    def resolve(name, base_pathname = nil, context = nil)
      puts "RESOLVING"
      name = Pathname.new(name)
      if base_pathname && base_pathname.to_s.size > 0
        puts "INSIDE IF"
        puts "CONTEXT: #{context}"
        root = Pathname.new(context.root_path)
        puts "RELATIVE PATH FROM"
        name = base_pathname.relative_path_from(root).join(name)
      end
      partial_name = name.dirname.join("_#{name.basename}")
      #@resolver ||= Resolver.new(context)
      #@resolver.resolve(name) || @resolver.resolve(partial_name)
      context.resolve(name) || context.resolve(partial_name)
    end

    SASS_EXTENSIONS = {
      ".css.sass" => :sass,
      ".css.scss" => :scss,
      ".sass" => :sass,
      ".scss" => :scss
    }

    def sass_file?(filename)
      filename = filename.to_s
      SASS_EXTENSIONS.keys.any?{|ext| filename[ext]}
    end

    def syntax(filename)
      filename = filename.to_s
      SASS_EXTENSIONS.each {|ext, syntax| return syntax if filename[(ext.size+2)..-1][ext]}
      nil
    end



  class Resolver

    attr_accessor :context

    def initialize(context)
      @context = context
    end

    def resolve(path, content_type = :self)
      options = {}
      options[:content_type] = content_type unless content_type.nil?
      context.resolve(path.to_s, options)
    rescue Sprockets::FileNotFound, Sprockets::ContentTypeMismatch
      nil
    end

    def source_path(path, ext)
      context.asset_paths.compute_source_path(path, ::Rails.application.config.assets.prefix, ext)
    end

    def public_path(path, scope = nil, options = {})
      context.asset_paths.compute_public_path(path, ::Rails.application.config.assets.prefix, options)
    end

    def process(path)
      context.environment[path].to_s
    end

    def image_path(img)
      context.image_path(img)
    end

    def video_path(video)
      context.video_path(video)
    end

    def audio_path(audio)
      context.audio_path(audio)
    end

    def javascript_path(javascript)
      context.javascript_path(javascript)
    end

    def stylesheet_path(stylesheet)
      context.stylesheet_path(stylesheet)
    end

    def font_path(font)
      context.font_path(font)
    end
  end


    #def context
      #options[:sprockets][:context]
    #end
    # ==========================================================================
        def find(name, options)
          # globs must be relative
          return if name =~ GLOB
          super
        end

        private
          def glob_imports(base, glob, options)
            contents = ""
            context = options[:sprockets][:context]
            each_globbed_file(base, glob, context) do |filename|
              next if filename == options[:filename]
              contents << "@import #{filename.inspect};\n"
            end
            return nil if contents == ""
            Sass::Engine.new(contents, options.merge(
              :filename => base,
              :importer => self,
              :syntax => :scss
            ))
          end

          def each_globbed_file(base, glob, context)
            raise ArgumentError unless glob == "*" || glob == "**/*"

            exts = extensions.keys.map { |ext| Regexp.escape(".#{ext}") }.join("|")
            sass_re = Regexp.compile("(#{exts})$")

            context.depend_on(base)

            Dir["#{base}/#{glob}"].sort.each do |path|
              if File.directory?(path)
                context.depend_on(path)
              elsif sass_re =~ path
                yield path
              end
            end
          end
      end

      module ERB
        def extensions
          {
            'css.erb'  => :scss_erb,
            'scss.erb' => :scss_erb,
            'sass.erb' => :sass_erb
          }.merge(super)
        end

        def erb_extensions
          {
            :scss_erb => :scss,
            :sass_erb => :sass
          }
        end

        def find_relative(*args)
          process_erb_engine(super)
        end

        def find(*args)
          process_erb_engine(super)
        end

        private
          def process_erb_engine(engine)
            if engine && engine.options[:sprockets] && syntax = erb_extensions[engine.options[:syntax]]
              template = Tilt::ERBTemplate.new(engine.options[:filename])
              contents = template.render(engine.options[:sprockets][:context], {})

              Sass::Engine.new(contents, engine.options.merge(:syntax => syntax))
            else
              engine
            end
          end
      end

      module Deprecated
        def extensions
          {
            'css.scss'     => :scss,
            'css.sass'     => :sass,
            'css.scss.erb' => :scss_erb,
            'css.sass.erb' => :sass_erb
          }.merge(super)
        end

        def find_relative(*args)
          deprecate_extra_css_extension(super)
        end

        def find(*args)
          deprecate_extra_css_extension(super)
        end

        private
          def deprecate_extra_css_extension(engine)
            if engine && filename = engine.options[:filename]
              if filename.end_with?('.css.scss')
                msg = "Extra .css in SCSS file is unnecessary. Rename #{filename} to #{filename.sub('.css.scss', '.scss')}."
              elsif filename.end_with?('.css.sass')
                msg = "Extra .css in SASS file is unnecessary. Rename #{filename} to #{filename.sub('.css.sass', '.sass')}."
              elsif filename.end_with?('.css.scss.erb')
                msg = "Extra .css in SCSS/ERB file is unnecessary. Rename #{filename} to #{filename.sub('.css.scss.erb', '.scss.erb')}."
              elsif filename.end_with?('.css.sass.erb')
                msg = "Extra .css in SASS/ERB file is unnecessary. Rename #{filename} to #{filename.sub('.css.sass.erb', '.sass.erb')}."
              end

              ActiveSupport::Deprecation.warn(msg) if msg
            end

            engine
          end
      end

      include Deprecated
      include ERB
      include Globbing

      # Allow .css files to be @import'd
      def extensions
        { 'css' => :scss }.merge(super)
      end
    end
  end
end
