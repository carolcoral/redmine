class LogoSettingsController < ApplicationController
  layout 'admin'
  before_action :require_admin

  def update
    settings = params[:settings] || {}
    
    # 验证文字logo长度
    if settings['logo_type'] == 'text' && settings['logo_text'].present?
      if settings['logo_text'].length > 30
        respond_to do |format|
          format.html {
            flash[:error] = l(:notice_error_update, message: '文字logo不能超过30个字符')
            redirect_to plugin_settings_path('redmine_logo')
          }
          format.json { render json: {error: '文字logo不能超过30个字符'}, status: :unprocessable_entity }
        end
        return
      end
    end
    
    image_base64 = nil
    
    # 处理图片上传 - 转换为base64存储
    if params[:logo_image_file].present? && params[:logo_image_file].respond_to?(:read)
      uploaded_file = params[:logo_image_file]
      Rails.logger.info "[LogoPlugin] Converting file to base64: #{uploaded_file.original_filename}, size: #{uploaded_file.size}"
      
      if uploaded_file.respond_to?(:original_filename) && uploaded_file.size > 0
        begin
          # 读取文件内容并转换为base64
          file_content = uploaded_file.read
          base64_data = Base64.strict_encode64(file_content)
          content_type = uploaded_file.content_type || 'image/png'
          
          # 构建data URI
          image_base64 = "data:#{content_type};base64,#{base64_data}"
          
          # 保存base64到settings
          settings['logo_image_base64'] = image_base64
          settings['logo_image_content_type'] = content_type
          
          Rails.logger.info "[LogoPlugin] File converted to base64, size: #{image_base64.length} characters"
        rescue => e
          Rails.logger.error "[LogoPlugin] Error converting file to base64: #{e.message}\n#{e.backtrace.join("\n")}"
          settings['logo_image_base64'] = ''
          settings['logo_image_content_type'] = ''
        end
      else
        Rails.logger.warn "[LogoPlugin] Invalid file upload"
        settings['logo_image_base64'] = ''
        settings['logo_image_content_type'] = ''
      end
    else
      # 对于所有情况（包括image类型但没有上传新文件，或切换到text），都保留之前的base64数据
      # 这样切换回图片时还能恢复显示
      current_settings = Setting.plugin_redmine_logo || {}
      settings['logo_image_base64'] = current_settings['logo_image_base64'] if current_settings['logo_image_base64'].present?
      settings['logo_image_content_type'] = current_settings['logo_image_content_type'] if current_settings['logo_image_content_type'].present?
    end
    
    # 保存设置
    Rails.logger.info "[LogoPlugin] Saving plugin settings with base64 image"
    Setting.plugin_redmine_logo = settings
    Rails.logger.info "[LogoPlugin] Settings saved successfully"
    
    respond_to do |format|
      format.html {
        flash[:notice] = l(:notice_successful_update)
        redirect_to plugin_settings_path('redmine_logo')
      }
      format.json { 
        render json: {
          success: true, 
          image_url: image_base64,
          message: l(:notice_successful_update)
        } 
      }
    end
  rescue => e
    Rails.logger.error "[LogoPlugin] Error in update: #{e.message}\n#{e.backtrace.join("\n")}"
    respond_to do |format|
      format.html {
        flash[:error] = l(:notice_error_update, message: e.message)
        redirect_to plugin_settings_path('redmine_logo')
      }
      format.json { 
        render json: {error: e.message}, status: :unprocessable_entity 
      }
    end
  end
end
