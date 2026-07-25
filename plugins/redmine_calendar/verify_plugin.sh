#!/bin/bash

echo "======================================"
echo "Redmine Calendar Plugin Verification"
echo "======================================"
echo ""

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDMINE_ROOT="$(dirname "$(dirname "$PLUGIN_DIR")")"

echo "Plugin directory: $PLUGIN_DIR"
echo "Redmine root: $REDMINE_ROOT"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check 1: Directory structure
echo "1. Checking directory structure..."
[ -f "$PLUGIN_DIR/init.rb" ]
print_status $? "init.rb exists"

[ -d "$PLUGIN_DIR/lib" ]
print_status $? "lib directory exists"

[ -d "$PLUGIN_DIR/app" ]
print_status $? "app directory exists"

[ -d "$PLUGIN_DIR/assets" ]
print_status $? "assets directory exists"

[ -d "$PLUGIN_DIR/config" ]
print_status $? "config directory exists"

# Check 2: Critical files
echo ""
echo "2. Checking critical files..."

CRITICAL_FILES=(
    "init.rb"
    "lib/redmine_calendar.rb"
    "lib/redmine_calendar/hooks.rb"
    "config/routes.rb"
)

all_files_exist=true
for file in "${CRITICAL_FILES[@]}"; do
    [ -f "$PLUGIN_DIR/$file" ]
    status=$?
    print_status $status "   $file"
    if [ $status -ne 0 ]; then
        all_files_exist=false
    fi
done

# Check 3: Plugin registration
echo ""
echo "3. Checking plugin registration..."

cd "$REDMINE_ROOT"

if bundle exec rails runner "exit(Redmine::Plugin.registered_plugins.key?(:redmine_calendar) ? 0 : 1)" 2>/dev/null; then
    print_status 0 "Plugin is registered"
    
    # Get plugin version
    version=$(bundle exec rails runner "puts Redmine::Plugin.registered_plugins[:redmine_calendar].version" 2>/dev/null)
    echo "   Version: $version"
else
    print_status 1 "Plugin is NOT registered"
    print_warning "Plugin may not be loaded. Check:"
    print_warning "  - Directory name is 'redmine_calendar'"
    print_warning "  - Plugin files are readable"
    print_warning "  - Redmine has been restarted"
fi

# Check 4: Hooks
echo ""
echo "4. Checking hooks..."

if bundle exec rails runner "exit(Redmine::Hook.hook_listeners[:view_layouts_base_html_head].any? { |l| l.to_s.include?('RedmineCalendar') } ? 0 : 1)" 2>/dev/null; then
    print_status 0 "HTML head hook is registered"
else
    print_status 1 "HTML head hook is NOT registered"
fi

# Check 5: Routes
echo ""
echo "5. Checking routes..."

if bundle exec rails runner "puts Rails.application.routes.routes.collect { |r| r.defaults[:controller] }.uniq.grep(/redmine_calendar/).any?" 2>/dev/null | grep -q "true"; then
    print_status 0 "Plugin routes are defined"
else
    print_status 1 "Plugin routes are NOT defined"
    print_warning "Run 'bundle exec rake routes' to check"
fi

# Check 6: Permissions
echo ""
echo "6. Checking permissions..."

if bundle exec rails runner "puts Redmine::AccessControl.permissions.any? { |p| p.name == :edit_calendar_issues }" 2>/dev/null | grep -q "true"; then
    print_status 0 "Plugin permissions are defined"
else
    print_status 1 "Plugin permissions are NOT defined"
fi

# Check 7: File permissions
echo ""
echo "7. Checking file permissions..."

if [ -r "$PLUGIN_DIR/init.rb" ]; then
    print_status 0 "Plugin files are readable"
else
    print_status 1 "Plugin files are NOT readable"
    print_warning "Check ownership and permissions"
fi

# Check 8: Log messages
echo ""
echo "8. Checking recent log messages..."

LOG_FILE="$REDMINE_ROOT/log/production.log"
if [ -f "$LOG_FILE" ]; then
    if grep -q "redminecalendar" "$LOG_FILE" 2>/dev/null; then
        print_status 0 "Plugin messages found in log"
        echo ""
        echo "   Recent plugin messages:"
        grep "redminecalendar" "$LOG_FILE" | tail -5 | sed 's/^/     /'
    else
        print_status 1 "No plugin messages in log"
        print_warning "Enable debug logging and restart Redmine"
    fi
else
    print_warning "Log file not found: $LOG_FILE"
fi

# Summary
echo ""
echo "======================================"
echo "Summary"
echo "======================================"

if [ "$all_files_exist" = true ]; then
    echo -e "${GREEN}✓ All critical files exist${NC}"
else
    echo -e "${RED}✗ Some critical files are missing${NC}"
fi

echo ""
echo "Next steps:"
echo "1. If plugin is not registered:"
echo "   - Ensure directory is named 'redmine_calendar'"
echo "   - Check file permissions"
echo "   - Restart Redmine: touch tmp/restart.txt"
echo ""
echo "2. If hooks are not registered:"
echo "   - Check lib/redmine_calendar/hooks.rb for syntax errors"
echo "   - Run: ruby -c lib/redmine_calendar/hooks.rb"
echo ""
echo "3. To test the plugin:"
echo "   - Open browser console (F12)"
echo "   - Navigate to a project calendar"
echo "   - Check for: '[RedmineCalendarSimple] Script loaded'"
echo ""
echo "4. For detailed debugging:"
echo "   - See PLUGIN_DEBUG.md"
echo "   - Check browser console for errors"
echo "   - Check redmine log for plugin messages"
echo ""

# Test URL
echo "Test URL format: http://your-redmine/projects/[project-id]/activity"
echo ""
echo "======================================"