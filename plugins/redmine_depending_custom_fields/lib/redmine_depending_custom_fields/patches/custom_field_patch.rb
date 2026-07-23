require_dependency 'custom_field'

# Extension for CustomField that triggers a callback on the field format after
# the record is saved. This allows formats to invalidate caches when their
# configuration changes.

module RedmineDependingCustomFields
  module Patches
    module CustomFieldPatch
      def self.prepended(base)
        base.after_save :dispatch_after_custom_field_save
      end

      private

      def dispatch_after_custom_field_save
        if format.respond_to?(:after_custom_field_save)
          format.after_custom_field_save(self)
        end
      end
    end
  end
end
