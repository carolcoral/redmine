module RedmineLogo
  class ViewListener < Redmine::Hook::ViewListener
    include LogoHelper

    def view_layouts_base_html_head(context = {})
      settings = Setting.plugin_redmine_logo || {}
      return '' if settings.blank? || settings['plugin_enabled'] != '1'

      css = generate_logo_css(settings)
      javascript = generate_logo_javascript(settings)
      custom_head_content = settings['custom_head_content'].to_s.strip

      # 仅在用户登录时插入自定义head内容
      should_insert_custom_content = User.current.logged?

      <<~HTML.html_safe
        #{'<style>' + css + '</style>' unless css.blank?}
        #{'<script>' + javascript + '</script>' unless javascript.blank?}
        #{custom_head_content.html_safe if should_insert_custom_content && custom_head_content.present?}
      HTML
    end

    def view_layouts_base_body_bottom(context = {})
      settings = Setting.plugin_redmine_logo || {}
      return '' if settings.blank? || settings['plugin_enabled'] != '1'

      logo_html = generate_logo_html(settings)
      insertion_script = generate_insertion_script(settings)
      
      <<~HTML.html_safe
        #{logo_html}
        <script>
          #{insertion_script}
        </script>
      HTML
    end

    private

    def generate_logo_css(settings)
      position = settings['logo_position'] || 'left'
      logo_height = settings['logo_height'] || '25px'
      
      css = []
      
      # Logo容器样式 - 自适应宽度
      if position == 'center'
        css << <<~CSS
          #redmine_logo-custom-logo-container {
            position: absolute;
            left: 50%;
            transform: translateX(-50%);
            z-index: 1000;
            display: flex;
            align-items: center;
            justify-content: center;
            height: #{logo_height};
            width: auto;
            pointer-events: auto;
          }
          /* 当logo居中时，修改#top-menu > ul的position为absolute */
          #top-menu > ul:first-child {
            position: absolute;
            left: 50%;
            transform: translateX(-50%);
            padding-left: 0;
            margin-left: 0;
          }
        CSS
      else # left
        css << <<~CSS
          #redmine_logo-custom-logo-container {
            position: relative;
            float: left;
            left: 0;
            z-index: 1000;
            display: flex;
            align-items: center;
            justify-content: flex-start;
            height: #{logo_height};
            width: auto;
            pointer-events: auto;
          }
        CSS
      end
      
      css << <<~CSS
        .redmine_logo-logo-text-modern {
          font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          text-decoration: none;
          position: relative;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          letter-spacing: -0.5px;
          transition: none; /* 移除过渡效果 */
          height: 100%;
          line-height: 1;
          white-space: nowrap;
          margin: 0;
          padding: 0;
        }
        /* 移除悬停效果 */
        .redmine_logo-logo-text-modern:hover {
          /* text-shadow: 0 2px 8px rgba(0, 0, 0, 0.15); */
        }
        /* 移除下划线动画 */
        .redmine_logo-logo-text-modern::after {
          /* display: none; */
        }
        .redmine_logo-logo-text-modern:hover::after {
          /* width: 100%; */
        }
        /* 首字母样式 */
        .redmine_logo-logo-first-letter {
          font-weight: bold;
        }
        #redmine_logo-custom-logo-image {
          max-width: 100%;
          max-height: 100%;
          height: 100%;
          width: auto;
          object-fit: contain;
          display: block !important;
          visibility: visible !important;
          margin: 0;
          padding: 0;
          opacity: 1 !important;
        }
        #redmine_logo-custom-logo-container a {
          display: flex;
          align-items: center;
          justify-content: center;
          height: 100%;
          text-decoration: none;
          margin: 0;
          padding: 0;
        }
        /* 不要修改top-menu的display属性，保持原有布局 */
        #top-menu {
          position: relative;
        }
        /* 图片logo场景下进一步缩减间距 */
        #redmine_logo-custom-logo-container img {
          max-width: 100px !important; /* 限制图片宽度 */
        }
        /* 右侧菜单保持原位置 */
        #top-menu ul + ul {
          margin-left: auto;
          padding-left: 0;
        }
        /* 修复页面抖动问题 - 移除transform和固定字体大小 */
        @media (max-width: 768px) {
          .redmine_logo-logo-text-modern { font-size: 18px !important; }
        }
        @media (max-width: 480px) {
          .redmine_logo-logo-text-modern { font-size: 16px !important; }
        }
      CSS
      
      css.join("\n")
    end

    def generate_logo_javascript(settings)
      <<~JAVASCRIPT
        document.addEventListener('DOMContentLoaded', function() {
          // 为文字logo添加动画效果
          const logoText = document.querySelector('#redmine_logo-custom-logo-text');
          if (logoText) {
            logoText.style.opacity = '0';
            logoText.style.transform = 'translateY(10px)';
            logoText.style.transition = 'opacity 0.6s cubic-bezier(0.4, 0, 0.2, 1), transform 0.6s cubic-bezier(0.4, 0, 0.2, 1)';
            setTimeout(function() {
              logoText.style.opacity = '1';
              logoText.style.transform = 'translateY(0)';
            }, 100);
          }

          // 为图片logo添加淡入效果
          const logoImage = document.querySelector('#redmine_logo-custom-logo-image');
          if (logoImage) {
            logoImage.style.opacity = '0';
            logoImage.style.transition = 'opacity 0.6s cubic-bezier(0.4, 0, 0.2, 1)';
            logoImage.addEventListener('load', function() {
              this.style.opacity = '1';
            });
          }
        });
      JAVASCRIPT
    end
    
    def generate_insertion_script(settings)
      <<~JAVASCRIPT
        (function() {
          function insertLogo() {
            const topMenu = document.getElementById('top-menu');
            const logoContainer = document.getElementById('redmine_logo-custom-logo-container');
            
            if (topMenu && logoContainer) {
              // 检查是否已经插入，避免重复操作
              if (logoContainer.parentNode === topMenu) {
                return;
              }
              
              // 使用更平滑的方式插入Logo，减少布局抖动
              logoContainer.style.visibility = 'hidden';
              logoContainer.style.display = 'flex';
              topMenu.insertBefore(logoContainer, topMenu.firstChild);
              
              // 使用requestAnimationFrame减少重排
              requestAnimationFrame(function() {
                requestAnimationFrame(function() {
                  logoContainer.style.visibility = 'visible';
                });
              });
            } else {
              setTimeout(insertLogo, 100);
            }
          }
          
          // 确保在DOM完全加载后执行
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function() {
              // 延迟执行，确保其他脚本已完成
              setTimeout(insertLogo, 50);
            });
          } else {
            setTimeout(insertLogo, 50);
          }
        })();
      JAVASCRIPT
    end

    def generate_logo_html(settings)
      link_path = home_url
      
      # 生成文字Logo（如果有base64图片数据且logo_type为text）
      text_content = ""
      if settings['logo_type'] == 'text'
        text = settings['logo_text'] || 'Redmine'
        first_letter = text[0]
        rest_of_text = text[1..-1]
        first_letter_color = settings['logo_first_letter_color'] || settings['logo_text_color'] || '#ffffff'
        font_size = settings['logo_text_font_size'] || '20px'
        
        # 计算其他字母的字体大小（小8%）
        if font_size.to_s.include?('px')
          base_size = font_size.to_f
          other_size = "#{(base_size * 0.92).round(1)}px"
        else
          other_size = font_size
        end
        
        # 创建带首字母颜色的文字
        content_tag = if rest_of_text.present?
          ActionController::Base.helpers.content_tag(:span, first_letter, 
            style: "color: #{first_letter_color}", 
            class: 'redmine_logo-logo-first-letter') +
          ActionController::Base.helpers.content_tag(:span, rest_of_text,
            style: "font-size: #{other_size}")
        else
          ActionController::Base.helpers.content_tag(:span, first_letter, 
            style: "color: #{first_letter_color}", 
            class: 'redmine_logo-logo-first-letter')
        end
        
        # 包装在logo-text-modern中
        text_content = ActionController::Base.helpers.content_tag(:span, 
          content_tag, 
          style: logo_text_styles(settings),
          id: 'redmine_logo-custom-logo-text',
          class: 'redmine_logo-logo-text-modern'
        )
      end
      
      # 生成图片Logo（如果有base64图片数据且logo_type为image）
      image_content = ""
      if settings['logo_image_base64'].present? && settings['logo_type'] == 'image'
        image_tag = ActionController::Base.helpers.image_tag(
          settings['logo_image_base64'],
          alt: settings['logo_text'] || 'Redmine',
          style: logo_image_styles(settings),
          id: 'redmine_logo-custom-logo-image'
        )
        image_content = <<~HTML
          <span id="redmine_logo-image-logo-wrapper" class="redmine_logo-logo-wrapper">
            #{image_tag}
          </span>
        HTML
      end
      
      # 生成完整的Logo容器，包含文字和图片两种类型
      <<~HTML
        <div id="redmine_logo-custom-logo-container" style="display:none;">
          <a href="#{link_path}" style="#{logo_link_styles(settings)}">
            <span id="redmine_logo-text-logo-wrapper" style="display: #{settings['logo_type'] == 'text' ? 'block' : 'none'};">
              #{text_content}
            </span>
            #{image_content}
          </a>
        </div>
      HTML
    end
  end
end
