# TILT Template
if defined?(Tilt)
  class RablTemplate < Tilt::Template
    def initialize_engine
      return if defined?(::Rabl)
      require_template_library 'rabl'
    end

    def prepare
      #left empty so each invocation has a new hash of options and new rabl engine for thread safety
    end

    def evaluate(context_scope, locals, &block)
      options = @options.merge(:source_location => file)
      ::Rabl::Engine.new(data, options).apply(context_scope, locals, &block).render
    end
  end

  Tilt.register 'rabl', RablTemplate
end

# Rails 6.X / 7.X / 8.X Template
if defined?(ActionView) && defined?(Rails)
  module ActionView
    module Template::Handlers
      class Rabl
        class_attribute :default_format
        self.default_format = :json

        def self.call(template, source)
          %{ ::Rabl::Engine.new(#{source.inspect}).
              apply(self, assigns.merge(local_assigns)).
              render }
        end # call
      end # rabl class
    end # handlers
  end

  ActionView::Template.register_template_handler :rabl, ActionView::Template::Handlers::Rabl
end
