# Set default options for Oj json parser (if exists)
begin
  require 'oj'
  Oj.default_options =  { :mode => :compat, :time_format => :ruby, :use_to_json => true }
rescue LoadError
end

module Rabl
  # Rabl.host
  class Configuration
    attr_accessor :include_json_root
    attr_accessor :include_child_root
    attr_accessor :enable_json_callbacks
    attr_writer   :json_engine
    attr_accessor :cache_sources
    attr_accessor :cache_all_output
    attr_accessor :escape_all_output
    attr_accessor :view_paths
    attr_accessor :cache_engine
    attr_accessor :raise_on_missing_attribute
    attr_accessor :perform_caching
    attr_accessor :use_read_multi
    attr_accessor :replace_nil_values_with_empty_strings
    attr_accessor :replace_empty_string_values_with_nil_values
    attr_accessor :exclude_nil_values
    attr_accessor :exclude_empty_values_in_collections
    attr_accessor :camelize_keys

    def initialize
      @include_json_root                            = true
      @include_child_root                           = true
      @enable_json_callbacks                        = false
      @json_engine                                  = nil
      @cache_sources                                = false
      @cache_all_output                             = false
      @escape_all_output                            = false
      @view_paths                                   = []
      @cache_engine                                 = Rabl::CacheEngine.new
      @perform_caching                              = false
      @use_read_multi                               = true
      @replace_nil_values_with_empty_strings        = false
      @replace_empty_string_values_with_nil_values  = false
      @exclude_nil_values                           = false
      @exclude_empty_values_in_collections          = false
      @camelize_keys                                = false
    end

    # @return The JSON engine used to encode Rabl templates into JSON
    def json_engine
      @json_engine || (defined?(::Oj) ? ::Oj : ::JSON)
    end

    # Allows config options to be read like a hash
    #
    # @param [Symbol] option Key for a given attribute
    def [](option)
      __send__(option)
    end
  end
end
