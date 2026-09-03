module Rabl
  module Sources
    include Helpers

    # Returns source for a given relative file
    # fetch_source("show", :view_path => "...") => "...contents..."
    def fetch_source(file, options = {})
      custom_view_path = Array(options[:view_path])

      Rabl.source_cache(file, custom_view_path) do
        view_paths = custom_view_path + Array(Rabl.configuration.view_paths)

        file_path = \
          if defined?(Rails) && context_scope.respond_to?(:view_paths)
            _view_paths = view_paths + Array(context_scope.view_paths.to_a)
            fetch_rails_source(file, options) || fetch_manual_template(_view_paths, file)
          else # generic template resolution
            fetch_manual_template(view_paths, file)
          end

        unless File.exist?(file_path.to_s)
          raise "Cannot find rabl template '#{file}' within registered (#{view_paths.map(&:to_s).inspect}) view paths!"
        end

        [File.read(file_path.to_s), file_path.to_s]
      end
    end

    private
      # Returns the rabl template path using the Rails template resolution mechanism
      def fetch_rails_source(file, options = {})
        source_format = request_format if defined?(request_format)
        return unless source_format && context_scope.respond_to?(:lookup_context)

        lookup_proc = lambda do |partial|
          # pull format directly from rails unless it is html
          request_format = context_scope.request.format.to_sym
          source_format = request_format unless request_format == :html
          context_scope.lookup_context.find(file, [], partial, [], { :formats => [source_format] })
        end

        template = lookup_proc.call(false) rescue nil
        template ||= lookup_proc.call(true) rescue nil
        template.identifier if template
      end

      # Returns the rabl template by looking up files within the view_path and specified file path
      def fetch_manual_template(view_path, file)
        Dir[File.join("{#{view_path.join(",")}}", "{#{file},#{partialized(file)}}" + ".{*.,}rabl")].first
      end

      # Returns a partialized version of a file path
      # partialized("v1/variants/variant") => "v1/variants/_variant"
      def partialized(file)
        partial_file = file.split(File::SEPARATOR)
        partial_file[-1] = "_#{partial_file[-1]}" unless partial_file[-1].start_with?("_")
        partial_file.join(File::SEPARATOR)
      end
  end # Sources
end # Rabl
