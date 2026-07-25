# frozen_string_literal: true

module AiAssistant
  class AiProvider < ActiveRecord::Base
    self.table_name = 'ai_providers'

    # ========== 常量 ==========
    # 服务商类型：tdp=TDP 平台，custom=其他 OpenAI 兼容接口
    PROVIDER_TYPES = %w[tdp custom].freeze

    # 名称下拉选项：国际前5 + 中国前5 + TDP
    PROVIDER_NAME_OPTIONS = [
      ['TDP', 'TDP'],
      ['自定义服务商（OPENAI协议）', '自定义服务商（OPENAI协议）'],
      ['OpenAI', 'OpenAI'],
      ['Anthropic (Claude)', 'Anthropic (Claude)'],
      ['Google (Gemini)', 'Google (Gemini)'],
      ['xAI (Grok)', 'xAI (Grok)'],
      ['Mistral AI', 'Mistral AI'],
      ['百度文心一言', '百度文心一言'],
      ['阿里通义千问', '阿里通义千问'],
      ['智谱清言 (GLM)', '智谱清言 (GLM)'],
      ['Kimi (月之暗面)', 'Kimi (月之暗面)'],
      ['DeepSeek', 'DeepSeek']
    ].freeze

    # 返回名称下拉选项，若当前名称不在标准列表则追加显示
    def self.name_options_for(provider)
      current = provider&.name
      options = PROVIDER_NAME_OPTIONS.dup
      if current.present? && options.none? { |_, value| value == current }
        options.unshift([current, current])
      end
      options
    end

    # ========== 验证 ==========
    validates :name, :slug, :provider_type, :api_url, :default_model, presence: true
    validates :slug, uniqueness: true, format: { with: /\A[a-z0-9_-]+\z/, message: :invalid }
    validates :provider_type, inclusion: { in: PROVIDER_TYPES }, allow_blank: true
    validates :api_url, format: { with: /\Ahttps?:\/\/.+/ }

    before_validation :set_default_provider_type, on: [:create, :update]
    validates :position, numericality: { only_integer: true }

    # ========== 范围 ==========
    scope :enabled,       -> { where(is_enabled: true) }
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

    def set_default_provider_type
      self.provider_type = 'custom' if provider_type.blank?
    end

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
