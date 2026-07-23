# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  # 钉钉登录相关路由
  resources :dingtalk_login, only: [] do
    collection do
      post :generate_qr_code  # 生成二维码
      get :callback          # 钉钉回调
    end
  end
  
  # 兼容旧版Redmine的路由定义方式
  if respond_to?(:get)
    get '/dingtalk_login/callback', to: 'dingtalk_login#callback'
    post '/dingtalk_login/generate_qr_code', to: 'dingtalk_login#generate_qr_code'
  end
end
