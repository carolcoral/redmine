# Redmine Calendar Plugin - Debug Guide

## Quick Status Check

Run this in your Redmine root directory:

```bash
# Check if plugin files exist
ls -la plugins/redmine_calendar/

# Check plugin registration
bundle exec rails runner "puts Redmine::Plugin.registered_plugins.keys"

# Check if hooks are loaded
bundle exec rails runner "puts Redmine::Hook.hook_listeners.keys"

# Check log for plugin messages
grep -i "redminecalendar" log/production.log
```

## Browser Debug Steps

### 1. Check if plugin assets are loaded

Open browser console (F12) and run:
```javascript
// Check if plugin marker exists
$('#redmine-calendar-plugin-loaded').length  // Should be 1

// Check if calendar data exists
$('#redmine-calendar-data').length  // Should be 1

// Check console for plugin logs
grepConsole('[RedmineCalendar]')
```

### 2. Check JavaScript errors

Look for errors like:
- `ReferenceError: $ is not defined`
- `TypeError: Cannot read property '...' of undefined`
- `404 Not Found` for plugin assets

### 3. Check if calendar elements are enhanced

```javascript
// Check enhanced days
$('.calendar-day-enhanced').length  // Should be > 0

// Check enhanced issues
$('.calendar-issue-enhanced').length  // Should be > 0

// Check data attributes
$('.calendar-day').first().data('date')  // Should return a date string
```

## Common Issues and Fixes

### Issue 1: Plugin not registered

**Symptom**: `Redmine::Plugin.registered_plugins[:redmine_calendar]` returns nil

**Fix**:
1. Check directory name: `mv redmine_calendar-<version> redmine_calendar`
2. Restart Redmine: `touch tmp/restart.txt`
3. Check file permissions

### Issue 2: Hooks not triggering

**Symptom**: No `[RedmineCalendar]` logs in production.log

**Fix**:
1. Verify `lib/redmine_calendar/hooks.rb` exists
2. Check for syntax errors: `ruby -c lib/redmine_calendar/hooks.rb`
3. Clear cache: `rm -rf tmp/cache`

### Issue 3: JavaScript not loading

**Symptom**: `$('#redmine-calendar-plugin-loaded').length` returns 0

**Fix**:
1. Check asset paths in hooks.rb
2. Verify files exist in `assets/javascripts/`
3. Check browser Network tab for 404 errors

### Issue 4: JavaScript errors

**Symptom**: Console shows errors like `$ is not defined`

**Fix**:
1. Ensure jQuery is loaded before plugin scripts
2. Check for conflicts with other plugins
3. Use browser debugger to find error location

## Manual Testing

### Test 1: Verify plugin registration

```bash
cd /path/to/redmine
bundle exec rails console -e production

# In console:
Redmine::Plugin.registered_plugins[:redmine_calendar]
# Should return plugin info, not nil
```

### Test 2: Verify hooks

```bash
bundle exec rails console -e production

# In console:
Redmine::Hook.hook_listeners[:view_layouts_base_html_head]
# Should include RedmineCalendar::Hooks
```

### Test 3: Test calendar view

```bash
curl -s http://your-redmine/projects/your-project/activity | grep -i "redmine-calendar"
# Should find plugin assets
```

## Log Analysis

### Enable debug logging

Add to `config/environments/production.rb`:
```ruby
config.log_level = :debug
```

### Check for plugin logs

```bash
tail -f log/production.log | grep -i "redminecalendar"
```

Expected log entries:
```
[RedmineCalendar] Plugin registered successfully
[RedmineCalendar] Hook view_layouts_base_html_head called for: CalendarsController
[RedmineCalendar] Loading assets for calendar page
[RedmineCalendar] Assets loaded successfully
[RedmineCalendar] Hook view_calendars_show_bottom called for: CalendarsController
[RedmineCalendar] Adding calendar enhancements
[RedmineCalendar] Enhancements rendered successfully
```

## Emergency Fix

If nothing else works, try this minimal version:

1. Backup current plugin:
```bash
mv plugins/redmine_calendar plugins/redmine_calendar_backup
```

2. Create minimal plugin:
```bash
mkdir -p plugins/redmine_calendar/lib/redmine_calendar
cat > plugins/redmine_calendar/init.rb << 'EOF'
require 'redmine'

Redmine::Plugin.register :redmine_calendar do
  name 'Redmine Calendar Minimal Test'
  version '0.1'
end

# Add a simple hook
class RedmineCalendarHook < Redmine::Hook::ViewListener
  def view_layouts_base_html_head(context)
    '<script>console.log("MINIMAL PLUGIN LOADED");</script>'
  end
end
EOF
```

3. Restart and check if "MINIMAL PLUGIN LOADED" appears in console

## Getting Help

If none of these steps work, provide:

1. **Redmine version**: `bundle exec rails runner "puts Redmine::VERSION"`
2. **Plugin list**: `ls plugins/`
3. **Log file**: `grep -A5 -B5 redminecalendar log/production.log`
4. **Browser info**: Console logs, Network tab
5. **File structure**: `find plugins/redmine_calendar -type f`

## Success Indicators

When the plugin works correctly, you should see:

✅ In server logs:
```
[RedmineCalendar] Plugin loaded successfully
[RedmineCalendar] Loading assets for calendar page
```

✅ In browser console:
```
[RedmineCalendarSimple] Script loaded
[RedmineCalendarSimple] DOM ready
[RedmineCalendarSimple] Calendar found, initializing...
[RedmineCalendarSimple] Enhanced X calendar days
[RedmineCalendarSimple] Enhanced X issues
[RedmineCalendarSimple] Initialization complete
```

✅ In browser elements:
- Calendar days have `class="calendar-day"` and `data-date="YYYY-MM-DD"`
- Issues have `class="calendar-issue"` and `draggable="true"`
- Right-click on issues shows a context menu