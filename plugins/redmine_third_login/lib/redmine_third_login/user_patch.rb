# frozen_string_literal: true

module RedmineThirdLogin
  module UserPatch
    extend ActiveSupport::Concern

    included do
      # 添加手机号字段的访问方法
      def mobile_phone
        custom_field = UserCustomField.find_by(name: '手机号')
        return nil unless custom_field
        
        custom_value = custom_values.find_by(custom_field_id: custom_field.id)
        custom_value&.value
      end

      def self.find_by_mobile_phone(phone)
        return nil if phone.blank?
        
        custom_field = UserCustomField.find_by(name: '手机号')
        return nil unless custom_field
        
        custom_value = CustomValue.where(
          customized_type: 'User',
          custom_field_id: custom_field.id,
          value: phone
        ).first
        
        return nil unless custom_value
        
        User.find_by(id: custom_value.customized_id)
      end
    end
  end
end
