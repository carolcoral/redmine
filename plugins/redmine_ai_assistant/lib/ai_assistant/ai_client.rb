# frozen_string_literal: true

require 'net/http'
require 'json'

module AiAssistant
  # Multi-provider AI Client -- 统一适配 OpenAI 兼容接口
  class AiClient
    attr_reader :provider, :model

    def initialize(provider = nil, model: nil)
      @provider = provider || default_provider
      @model    = model    || @provider.default_model

      raise ArgumentError, 'No AI provider configured or enabled' if @provider.nil?
      raise ArgumentError, 'API key not configured for this provider' if @provider.api_key.blank?
    end

    # 执行对话（支持上下文 messages）
    def chat(messages, **options)
      body = build_request_body(messages, options)
      uri  = URI(@provider.chat_endpoint)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 10
      http.read_timeout = (options[:timeout] || 120)

      request = Net::HTTP::Post.new(uri.path, @provider.headers)
      request.body = body.to_json

      response = http.request(request)
      parse_response(response)
    rescue Net::OpenTimeout, Net::ReadTimeout
      { error: 'AI 服务请求超时，请稍后重试' }
    rescue StandardError => e
      { error: "AI 服务异常: #{e.message}" }
    end

    def self.default_provider
      AiProvider.enabled.ordered.first
    end

    private

    def default_provider
      self.class.default_provider
    end

    def build_request_body(messages, options)
      body = {
        model:    @model,
        messages: messages,
        stream:   false,
        temperature: options[:temperature] || 0.7,
        max_tokens:  options[:max_tokens]  || 4096
      }

      # 注入 provider 特定参数
      extra = @provider.extra_settings
      body.merge!(extra.select { |k, _v| k.start_with?('param_') })
          .transform_keys! { |k| k.to_s.sub('param_', '').to_sym }

      body
    end

    def parse_response(response)
      case response.code.to_i
      when 200
        data = JSON.parse(response.body)
        choice = data.dig('choices', 0, 'message')
        usage  = data['usage'] || {}

        {
          content:      choice['content'],
          role:         choice['role'],
          model:        data['model'],
          tokens_used:  usage['total_tokens'] || 0,
          prompt_tokens:  usage['prompt_tokens'] || 0,
          completion_tokens: usage['completion_tokens'] || 0
        }
      when 401
        { error: 'AI 服务认证失败，请检查 API Key 配置' }
      when 429
        { error: 'AI 服务请求过于频繁，请稍后重试' }
      when 500..599
        { error: "AI 服务异常 (#{response.code})，请稍后重试" }
      else
        data = JSON.parse(response.body) rescue {}
        { error: data['error']&.[]('message') || "AI 服务返回异常 (#{response.code})" }
      end
    end
  end
end
