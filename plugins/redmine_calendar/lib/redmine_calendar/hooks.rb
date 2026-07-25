module RedmineCalendar
  class Hooks < Redmine::Hook::ViewListener
    # Add plugin assets to calendar pages
    def view_layouts_base_html_head(context = {})
      controller = context[:controller]
      
      # Only load on calendar pages
      if controller && controller.class.name == 'CalendarsController'
        # Load CSS
        css = stylesheet_link_tag('redmine_calendar', plugin: 'redmine_calendar')
        
        # Load JavaScript - use simple version first
        js = javascript_include_tag('redmine_calendar_simple', plugin: 'redmine_calendar')
        
        # Marker to indicate plugin is loaded
        marker = "<div id='redmine-calendar-plugin-loaded' style='display:none;'></div>".html_safe
        
        return css + js + marker
      end
      
      ''
    end
    
    # Add enhancements to calendar view
    def view_calendars_show_bottom(context = {})
      controller = context[:controller]
      
      if controller && controller.class.name == 'CalendarsController'
        # Render enhancements partial
        begin
          context[:controller].send(:render_to_string, 
            partial: 'hooks/redmine_calendar/view_calendars_show_bottom',
            locals: { project: context[:project] }
          )
        rescue => e
          Rails.logger.error "[RedmineCalendar] Failed to render enhancements: #{e.message}"
          ''
        end
      else
        ''
      end
    end
  end
end