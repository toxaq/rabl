require 'action_view'

module Rabl
  class Digestor < ActionView::Digestor
    private
      def dependency_digest
        template_digests = (dependencies - [template.virtual_path]).collect do |template_name|
          Digestor.digest(:name => template_name, :finder => finder)
        end

        (template_digests + injected_dependencies).join("-")
      end
  end
end
