#!/bin/bash

# Redmine Calendar Plugin Validation Script
# 验证插件文件完整性

echo "Redmine Calendar Plugin Validation"
echo "=================================="
echo ""

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_FILES=(
  "init.rb"
  "config/routes.rb"
  "lib/redmine_calendar.rb"
  "lib/redmine_calendar/hooks.rb"
  "lib/redmine_calendar/calendars_controller_patch.rb"
  "app/controllers/redmine_calendar_controller.rb"
  "app/helpers/redmine_calendar_helper.rb"
  "assets/javascripts/redmine_calendar.js"
  "assets/stylesheets/redmine_calendar.css"
  "config/locales/en.yml"
  "config/locales/zh.yml"
  "app/views/settings/_redmine_calendar_settings.html.erb"
  "app/views/hooks/redmine_calendar/_view_calendars_show_bottom.html.erb"
)

all_exist=true

for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "$PLUGIN_DIR/$file" ]; then
    echo "✓ $file"
  else
    echo "✗ $file (MISSING)"
    all_exist=false
  fi
done

echo ""
if [ "$all_exist" = true ]; then
  echo "✅ All required files exist!"
  echo ""
  echo "Plugin is ready for installation."
  echo ""
  echo "Next steps:"
  echo "1. Copy this directory to Redmine plugins folder:"
  echo "   cp -r '$PLUGIN_DIR' /path/to/redmine/plugins/"
  echo "2. Ensure directory is named 'redmine_calendar'"
  echo "3. Run: cd /path/to/redmine && bundle install"
  echo "4. Restart Redmine"
  exit 0
else
  echo "❌ Some files are missing!"
  echo ""
  echo "Please check the plugin archive and ensure all files are present."
  exit 1
fi