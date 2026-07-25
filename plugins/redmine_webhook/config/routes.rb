Rails.application.routes.draw do
  # 为项目级别的 webhook 设置定义路由
  get '/projects/:project_id/webhook_settings', to: 'webhook_settings#index', as: 'project_webhook_settings'
  put '/projects/:project_id/webhook_settings', to: 'webhook_settings#update', as: 'update_project_webhook_settings'
end