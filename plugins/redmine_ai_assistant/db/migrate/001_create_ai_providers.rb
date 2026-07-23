# frozen_string_literal: true

class CreateAiProviders < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_providers do |t|
      t.string  :name,            null: false
      t.string  :slug,            null: false
      t.string  :provider_type,   null: false  # openai, glm, minimax, kimi, deepseek, custom
      t.string  :api_url,         null: false
      t.text    :api_key,         null: false  # encrypted
      t.string  :default_model,   null: false
      t.text    :available_models              # JSON array of model names
      t.text    :settings                      # JSON extra settings
      t.boolean :is_enabled,      null: false, default: true
      t.boolean :is_builtin,      null: false, default: false
      t.integer :position,        null: false, default: 0

      t.timestamps
    end

    add_index :ai_providers, :slug, unique: true
    add_index :ai_providers, :is_enabled
    add_index :ai_providers, :position

    # ========== 内置全球主流 AI 服务商 ==========
    reversible do |dir|
      dir.up do
        providers = [
          {
            name: 'OpenAI',
            slug: 'openai',
            provider_type: 'openai',
            api_url: 'https://api.openai.com/v1',
            default_model: 'gpt-4o',
            available_models: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'].to_json,
            is_builtin: true,
            position: 1
          },
          {
            name: 'DeepSeek',
            slug: 'deepseek',
            provider_type: 'deepseek',
            api_url: 'https://api.deepseek.com/v1',
            default_model: 'deepseek-chat',
            available_models: ['deepseek-chat', 'deepseek-reasoner'].to_json,
            is_builtin: true,
            position: 2
          },
          {
            name: 'GLM (智谱清言)',
            slug: 'glm',
            provider_type: 'glm',
            api_url: 'https://open.bigmodel.cn/api/paas/v4',
            default_model: 'glm-4-flash',
            available_models: ['glm-4-plus', 'glm-4-flash', 'glm-4-air'].to_json,
            is_builtin: true,
            position: 3
          },
          {
            name: 'Kimi (月之暗面)',
            slug: 'kimi',
            provider_type: 'kimi',
            api_url: 'https://api.moonshot.cn/v1',
            default_model: 'moonshot-v1-8k',
            available_models: ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'].to_json,
            is_builtin: true,
            position: 4
          },
          {
            name: 'MiniMax',
            slug: 'minimax',
            provider_type: 'minimax',
            api_url: 'https://api.minimax.chat/v1',
            default_model: 'abab7-chat',
            available_models: ['abab7-chat', 'abab6.5s-chat'].to_json,
            is_builtin: true,
            position: 5
          }
        ]

        now = Time.current
        providers.each do |attrs|
          attrs[:api_key] = ''
          attrs[:created_at] = now
          attrs[:updated_at] = now
          execute(
            "INSERT INTO ai_providers (#{attrs.keys.join(', ')}) " \
            "VALUES (#{attrs.values.map { |v| ActiveRecord::Base.connection.quote(v) }.join(', ')})"
          )
        end
      end
    end
  end
end
