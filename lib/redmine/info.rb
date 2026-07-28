# frozen_string_literal: true

# Redmine++ - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
# Copyright (C) 2026  Redmine++ Contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

module Redmine
  module Info
    class << self
      def app_name; 'Redmine++' end
      def url; 'https://github.com/carolcoral/redmine' end
      def help_url; 'https://www.redmine.org/guide' end
      def versioned_name; "#{app_name} #{Redmine::VERSION}" end

      def environment
        s = +"Environment:\n"
        s << [
          ["Redmine version", Redmine::VERSION],
          ["Ruby version", "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"],
          ["Rails version", Rails::VERSION::STRING],
          ["Environment", Rails.env],
          ["Database adapter", ActiveRecord::Base.connection.adapter_name],
          ["Mailer queue", ActionMailer::MailDeliveryJob.queue_adapter.class.name],
          ["Mailer delivery", ActionMailer::Base.delivery_method]
        ].map {|info| "  %-30s %s" % info}.join("\n") + "\n"

        theme_string = ''
        theme_string += (Setting.ui_theme.blank? ? 'Default' : Setting.ui_theme.capitalize)
        unless Setting.ui_theme.blank? ||
          Redmine::Themes.theme(Setting.ui_theme).nil? ||
          !Redmine::Themes.theme(Setting.ui_theme).javascripts.include?('theme')
          theme_string += ' (includes JavaScript)'
        end

        s << "Redmine settings:\n"
        s << [
          ["Redmine theme", theme_string]
        ].map {|settings| "  %-30s %s" % settings}.join("\n") + "\n"

        s << "SCM:\n"
        Redmine::Scm::Base.all.each do |scm|
          scm_class = "Repository::#{scm}".constantize
          if scm_class.scm_available
            s << "  %-30s %s\n" % [scm, scm_class.scm_version_string]
          end
        end

        s << "Redmine plugins:\n"
        plugins = Redmine::Plugin.all
        if plugins.any?
          s << plugins.map {|plugin| "  %-30s %s" % [plugin.id.to_s, plugin.version.to_s]}.join("\n")
        else
          s << "  no plugin installed"
        end
      end
    end
  end
end
