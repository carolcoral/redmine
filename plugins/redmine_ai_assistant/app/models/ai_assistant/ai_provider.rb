# frozen_string_literal: true

module AiAssistant
  class AiProvider < ActiveRecord::Base
    self.table_name = 'ai_providers'

    # ========== 常量 ==========
    PROVIDER_TYPES = %w[openai glm minimax kimi deepseek custom].freeze

    # ========== 验证 ==========
    validates :name, :slug, :provider_type, :api_url, :default_model, presence: true
    validates :slug, uniqueness: true, format: { with: /\A[a-z0-9_-]+\z/, message: :invalid }
    validates :provider_type, inclusion: { in: PROVIDER_TYPES }
    validates :api_url, format: { with: /\Ahttps?:\/\/.+/ }
    validates :position, numericality: { only_integer: true }

    # ========== 范围 ==========
    scope :enabled,       -> { where(is_enabled: true) }
    scope :builtin,       -> { where(is_builtin: true) }
    scope :custom,        -> { where(is_builtin: false) }
    scope :ordered,       -> { order(position: :asc, id: :asc) }

    # ========== 加解密 ==========
    def api_key=(value)
      super(encrypt_value(value))
    end

    def api_key
      decrypt_value(super)
    end

    # ========== 业务方法 ==========
    def enabled?
      is_enabled?
    end

    def builtin?
      is_builtin?
    end

    def available_model_list
      return [default_model] if available_models.blank?

      JSON.parse(available_models)
    rescue JSON::ParserError
      [default_model]
    end

    def extra_settings
      return {} if settings.blank?

      JSON.parse(settings)
    rescue JSON::ParserError
      {}
    end

    def headers
      {
        'Content-Type'  => 'application/json',
        'Authorization' => "Bearer #{api_key}"
      }
    end

    def chat_endpoint
      "#{api_url}/chat/completions"
    end

    private

    def encrypt_value(value)
      return '' if value.blank?

      key = encryption_key
      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.encrypt
      cipher.key = key
      iv = cipher.random_iv
      encrypted = cipher.update(value) + cipher.final
      Base64.strict_encode64(iv + encrypted)
    end

    def decrypt_value(encrypted_value)
      return '' if encrypted_value.blank?

      key = encryption_key
      data = Base64.strict_decode64(encrypted_value)
      iv = data[0..15]
      ciphertext = data[16..]
      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      cipher.update(ciphertext) + cipher.final
    rescue StandardError
      ''
    end

    def encryption_key
      secret = Rails.application.secret_key_base ||
               Rails.application.credentials.secret_key_base ||
               'redmine_ai_assistant_fallback_key_do_not_use_in_production'
      Digest::SHA256.digest(secret.to_s)
    end
  end
end
