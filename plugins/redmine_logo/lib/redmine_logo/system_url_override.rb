module RedmineLogo
  module SystemUrlOverride
    def self.apply!
      return if @applied
      
      # 覆盖 ApplicationController 的 home_url 方法
      if defined?(ApplicationController)
        ApplicationController.class_eval do
          # 保存原始方法
          unless method_defined?(:original_home_url)
            alias_method :original_home_url, :home_url if method_defined?(:home_url)
          end
          
          def home_url(options = {})
            custom_url = get_custom_system_url
            return custom_url if custom_url.present?
            
            # 调用原始的 home_url
            if respond_to?(:original_home_url)
              original_home_url(options)
            else
n              # 如果没有原始方法，使用默认实现
              url = (Redmine::Configuration['protocol'] || 'http') + '://' + (Redmine::Configuration['host_name'] || 'localhost:3000')
              url
            end
          end
          
          private
          
          def get_custom_system_url
            settings = Setting.plugin_redmine_logo
            return nil unless settings.is_a?(Hash)
            
            url = settings['custom_system_url'].to_s.strip
            return nil if url.blank?
            
            # 确保URL格式正确
            url = "https://#{url}" unless url.start_with?('http://', 'https://')
            url
          rescue
            nil
          end
        end
      end
      
      # 覆盖 Setting.host_name 以影响邮件和其他地方
      if defined?(Setting)
        Setting.class_eval do
          class << self
            # 保存原始方法
            unless method_defined?(:original_host_name)
              alias_method :original_host_name, :host_name if method_defined?(:host_name)
            end
            
            def host_name
              custom_url = get_custom_system_url_from_plugin
              return extract_host_from_url(custom_url) if custom_url.present?
              
              # 调用原始的 host_name
              if respond_to?(:original_host_name)
                original_host_name
              else
                # 如果没有原始方法，使用默认实现
                Redmine::Configuration['host_name'] || 'localhost:3000'
              end
            end
            
            private
            
            def get_custom_system_url_from_plugin
              settings = Setting.plugin_redmine_logo
              return nil unless settings.is_a?(Hash)
              
              url = settings['custom_system_url'].to_s.strip
              return nil if url.blank?
              
              # 确保URL格式正确
              url = "https://#{url}" unless url.start_with?('http://', 'https://')
              url
            rescue
              nil
            end
            
            def extract_host_from_url(url)
              # 从URL中提取 host:port 部分
              uri = URI.parse(url)
              host = uri.host
              port = uri.port
              
              if port && port != 80 && port != 443
                "#{host}:#{port}"
              else
                host
              end
            rescue
              nil
            end
          end
        end
      end
      
      # 覆盖 Setting.protocol 以影响邮件和其他地方
      if defined?(Setting)
        Setting.class_eval do
          class << self
            # 保存原始方法
            unless method_defined?(:original_protocol)
              alias_method :original_protocol, :protocol if method_defined?(:protocol)
            end
            
            def protocol
              custom_url = get_custom_protocol_from_plugin
              return custom_url if custom_url.present?
              
              # 调用原始的 protocol
              if respond_to?(:original_protocol)
                original_protocol
              else
                # 如果没有原始方法，使用默认实现
                Redmine::Configuration['protocol'] || 'http'
              end
            end
            
            private
            
            def get_custom_protocol_from_plugin
              settings = Setting.plugin_redmine_logo
              return nil unless settings.is_a?(Hash)
              
              url = settings['custom_system_url'].to_s.strip
              return nil if url.blank?
              
              # 从URL中提取协议
              uri = URI.parse(url)
              uri.scheme
            rescue
              nil
            end
          end
        end
      end
      
      @applied = true
    end
  end
end
