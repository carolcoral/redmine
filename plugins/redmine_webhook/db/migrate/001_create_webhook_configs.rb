class CreateWebhookConfigs < ActiveRecord::Migration[7.2]
  def change
    create_table :webhook_configs do |t|
      t.integer :project_id, null: false
      t.string :webhook_url, null: false
      t.string :secret_token
      t.boolean :enabled, default: false, null: false
      # 使用 text 类型存储序列化数据
      t.text :status_templates
      t.text :enabled_statuses
      
      t.timestamps
    end
    
    add_index :webhook_configs, :project_id, unique: true
    add_index :webhook_configs, :enabled
  end
end