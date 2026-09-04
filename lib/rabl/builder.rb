require 'active_support/inflector' # for the sake of camelcasing keys

module Rabl
  class Builder
    include Helpers
    include Partials

    SETTING_TYPES = {
      :attributes => :name,
      :node       => :name,
      :child      => :data,
      :glue       => :data,
      :extends    => :file
    } unless const_defined?(:SETTING_TYPES)

    # Constructs a new rabl hash based on given object and options
    # options = { :format => "json", :root => true, :child_root => true,
    #   :attributes, :node, :child, :glue, :extends }
    #
    def initialize(object, settings = {}, options = {})
      @_object = object

      @settings       = settings
      @options        = options
      @_context_scope = options[:scope]
      @_view_path     = options[:view_path]
      @configuration  = Rabl.configuration
    end

    def engines
      return @_engines if defined?(@_engines)

      @_engines = []

      # Append onto @_engines
      compile_settings(:extends)
      compile_settings(:child)
      compile_settings(:glue)

      @_engines
    end

    def replace_engine(engine, value)
      engines[engines.index(engine)] = value
    end

    def to_hash(object = nil, settings = nil, options = nil)
      @_object = object           if object
      @options.merge!(options)    if options
      @settings.merge!(settings)  if settings

      cache_results do
        @_result = {}

        # Merges directly into @_result
        compile_settings(:attributes)

        merge_engines_into_result

        # Merges directly into @_result
        compile_settings(:node)

        replace_nil_values          if @configuration.replace_nil_values_with_empty_strings
        replace_empty_string_values if @configuration.replace_empty_string_values_with_nil_values
        remove_nil_values           if @configuration.exclude_nil_values

        result = @_result
        result = { @options[:root_name] => result } if @options[:root_name].present?
        result
      end
    end

    protected
      def replace_nil_values
        @_result = deep_replace_nil_values(@_result)
      end

      def deep_replace_nil_values(hash)
        hash.inject({}) do |new_hash, (k, v)|
          new_hash[k] = if v.is_a?(Hash)
            deep_replace_nil_values(v)
          else
            v.nil? ? '' : v
          end
          new_hash
        end
      end

      def replace_empty_string_values
        @_result = deep_replace_empty_string_values(@_result)
      end

      def deep_replace_empty_string_values(hash)
        hash.inject({}) do |new_hash, (k, v)|
          new_hash[k] = if v.is_a?(Hash)
            deep_replace_empty_string_values(v)
          else
            (!v.nil? && v != "") ? v : nil
          end

          new_hash
        end
      end

      def remove_nil_values
        @_result = @_result.inject({}) do |new_hash, (k, v)|
          new_hash[k] = v unless v.nil?
          new_hash
        end
      end

      def compile_settings(type)
        settings = @settings[type]
        return if settings.nil? || settings.empty?

        settings_type = SETTING_TYPES[type]
        if type == :child || type == :glue
          # the setting itself is passed along so the engine compiled for
          # it can be reused across the items of a collection
          settings.each do |setting|
            send(type, setting[settings_type], setting[:options] || {}, setting, &setting[:block])
          end
        else
          settings.each do |setting|
            send(type, setting[settings_type], setting[:options] || {}, &setting[:block])
          end
        end
      end

      def merge_engines_into_result
        engines.each do |engine|
          case engine
          when Hash
            # engine was stored in the form { name => #<Engine> }
            engine.each do |key, value|
              engine[key] = value.render if value.is_a?(Engine)
            end
          when Engine
            engine = engine.render
          end

          @_result.merge!(engine) if engine.is_a?(Hash)
        end
      end

      # Indicates an attribute or method should be included in the json output
      # attribute :foo, :as => "bar"
      # attribute :foo, :as => "bar", :if => lambda { |m| m.foo }
    def attribute(name, options = {}, &block)
        return unless @_object

        if block_given?
          result = call_block(block)
          return unless result.is_a?(Array)
          result.each do |name|
            @_result[name] = data_object_attribute(name)
          end
        else
          return unless attribute_present?(name) && resolve_condition(options)

          attribute = data_object_attribute(name)
          name = create_key(options[:as] || name)
          @_result[name] = attribute
        end
      end
      alias_method :attributes, :attribute

      # Creates an arbitrary node that is included in the json output
      # node(:foo) { "bar" }
      # node(:foo, :if => lambda { |m| m.foo.present? }) { "bar" }
      def node(name, options = {}, &block)
        return unless resolve_condition(options)
        return if @options.has_key?(:except) && [@options[:except]].flatten.include?(name)

        result = call_block(block)
        if name.present?
          @_result[create_key(name)] = result
        elsif result.is_a?(Hash) # merge hash into root hash
          @_result.merge!(result)
        end
      end
      alias_method :code, :node

      # Creates a child node that is included in json output
      # child(@user) { attribute :full_name }
      # child(@user => :person) { ... }
      # child(@users => :people) { ... }
      def child(data, options = {}, setting = nil, &block)
        return unless data.present? && resolve_condition(options)

        name   = is_name_value?(options[:root]) ? options[:root] : data_name(data)
        object = data_object(data)

        engine_options = @options.slice(:child_root)
        engine_options[:root] = is_collection?(object) && options.fetch(:object_root, @options[:child_root]) # child @users
        engine_options[:object_root_name] = options[:object_root] if is_name_value?(options[:object_root])

        object = { object => name } if data.is_a?(Hash) && object # child :users => :people

        engines << { create_key(name) => setting_to_engine(setting, object, engine_options, &block) }
      end

      # Glues data from a child node to the json_output
      # glue(@user) { attribute :full_name => :user_full_name }
      def glue(data, options = {}, setting = nil, &block)
        return unless data.present? && resolve_condition(options)

        object = data_object(data)
        engine = setting_to_engine(setting, object, { :root => false }, &block)
        engines << engine if engine
      end

      # Builds the engine for a child/glue declaration. Within a collection
      # every item shares the same declaration (setting), so the engine
      # compiled for the first item is re-applied to subsequent items
      # instead of constructing a new engine per item. Reuse is skipped
      # when engines must stay distinct for the read_multi cache lookup.
      def setting_to_engine(setting, object, engine_options, &block)
        reusable = setting && !@options[:read_multi]

        if reusable && (engine = setting[:_engine]) && setting[:_engine_options] == engine_options
          return nil if object.nil?

          return engine.reapply({ :object => object, :parent_object => @_object, :locals => engine_options[:locals] }, &block)
        end

        saved_options = engine_options.dup if reusable

        engine_options[:parent_object] = @_object
        engine = object_to_engine(object, engine_options, &block)

        if reusable && engine.is_a?(Engine)
          setting[:_engine]         = engine
          setting[:_engine_options] = saved_options
        end

        engine
      end

      # Extends an existing rabl template with additional attributes in the block
      # extends("users/show") { attribute :full_name }
      def extends(file, options = {}, &block)
        return unless resolve_condition(options)

        options = @options.slice(:child_root).merge!(:object => @_object).merge!(options)
        engines << partial_as_engine(file, options, &block)
      end

      # Invokes a node/attribute block with the current object, also passing
      # the parent object through when the block asks for a second argument
      def call_block(block)
        if block.arity >= 0 && block.arity <= 1
          block.call(@_object)
        else
          block.call(@_object, @options[:parent_object])
        end
      end

      # Evaluate conditions given a symbol/proc/lambda/variable to evaluate
      def call_condition_proc(condition, object)
        case condition
        when Proc   then condition.call(object)
        when Symbol then condition.to_proc.call(object)
        else             condition
        end
      end

      # resolve_condition(:if => true) => true
      # resolve_condition(:if => 'Im truthy') => true
      # resolve_condition(:if => lambda { |m| false }) => false
      # resolve_condition(:unless => lambda { |m| false }) => true
      # resolve_condition(:unless => lambda { |m| false }, :if => proc { true}) => true
      def resolve_condition(options)
        return true if options.empty?

        result = true
        result &&=  call_condition_proc(options[:if], @_object)     if
          options.key?(:if)
        result &&= !call_condition_proc(options[:unless], @_object) if
          options.key?(:unless)
        result
      end

    private
      # Checks if an attribute is present. If not, check if the configuration specifies that this is an error
      # attribute_present?(created_at) => true
      def attribute_present?(name)
        @_object.respond_to?(name) ||
          (@configuration.raise_on_missing_attribute &&
           raise("Failed to render missing attribute #{name}"))
      end

      # Returns a guess at the format in this context_scope
      # request_format => "json"
      def request_format
        format = @options[:format]
        format = "json" if !format || format == "hash"
        format
      end

      # Caches the results of the block based on object cache_key
      # cache_results { compile_hash(options) }
      def cache_results(&block)
        if template_cache_configured? && @configuration.cache_all_output && @_object.respond_to?(:cache_key)
          cache_key = [@_object, @options[:root_name], @options[:format]]

          fetch_result_from_cache(cache_key, &block)
        else # skip cache
          yield
        end
      end

      def create_key(name)
        if @configuration.camelize_keys
          name.to_s.camelize(@configuration.camelize_keys == :upper ? :upper : :lower).to_sym
        else
          name.to_sym
        end
      end
  end
end
