# Redmine Calendar Plugin - Problem Resolution

## Problem Summary

**Issue**: All plugin features are not working. The calendar still uses Redmine's default functionality.

**Root Causes Identified**:
1. Plugin may not be registered correctly with Redmine
2. Hooks may not be triggering on calendar pages
3. JavaScript files may not be loading
4. JavaScript errors preventing functionality
5. CSS selectors may not match Redmine's HTML structure

## Solutions Implemented

### 1. Fixed Plugin Loading (`init.rb`)

**Changes Made**:
- Simplified plugin registration
- Moved all requires to `after_initialize` block
- Added explicit eager loading
- Added logging to track plugin loading

**Key Code**:
```ruby
Rails.configuration.after_initialize do
  require_dependency 'redmine_calendar'
  require_dependency 'redmine_calendar/hooks'
  require_dependency 'redmine_calendar/calendars_controller_patch'
  
  CalendarsController.include(RedmineCalendar::CalendarsControllerPatch)
  
  Rails.logger.info "[RedmineCalendar] Plugin loaded successfully"
end
```

### 2. Enhanced Hooks (`lib/redmine_calendar/hooks.rb`)

**Changes Made**:
- Added detailed logging to track hook execution
- Expanded detection of calendar controllers
- Added error handling with try/catch blocks
- Split into two hooks: `view_layouts_base_html_head` and `view_calendars_show_bottom`

**Key Code**:
```ruby
def view_layouts_base_html_head(context = {})
  controller = context[:controller]
  Rails.logger.info "[RedmineCalendar] Hook called for: #{controller.class.name}"
  
  if controller && (controller.class.name == 'CalendarsController' || 
                   controller.controller_name == 'calendars')
    # Load assets
  end
end
```

### 3. Simplified JavaScript (`redmine_calendar_simple.js`)

**Changes Made**:
- Created a new, simplified JavaScript file
- Removed complex dependencies and dependencies
- Added extensive console logging for debugging
- Used more reliable event delegation
- Added automatic retries for AJAX navigation

**Key Features**:
- Console logs at every step
- Automatic DOM scanning and enhancement
- Error handling with try/catch
- Visual feedback (cursor changes, opacity changes)
- Debug function accessible from console

### 4. Debug Helper (`redmine_calendar_debug.js`)

**Changes Made**:
- Auto-runs tests when page loads
- Checks for all required elements
- Validates event listeners
- Provides manual test functions

## Testing the Fixes

### Step 1: Run Verification Script

```bash
cd /Users/liuxuewen/workspace/redmine/redmine-plugins/redmine_calendar
./verify_plugin.sh
```

This will check:
- All critical files exist
- Plugin is registered with Redmine
- Hooks are loaded
- Routes are defined
- Permissions are set
- Recent log messages

Expected output should show mostly ✓ (green checkmarks)

### Step 2: Restart Redmine

```bash
cd /path/to/redmine
touch tmp/restart.txt
```

### Step 3: Check Logs

```bash
tail -f log/production.log | grep -i "redminecalendar"
```

You should see:
```
[RedmineCalendar] Plugin registered successfully
[RedmineCalendar] Plugin loaded successfully
[RedmineCalendar] Hook view_layouts_base_html_head called for: CalendarsController
[RedmineCalendar] Loading assets for calendar page
[RedmineCalendar] Assets loaded successfully
```

### Step 4: Browser Console Check

1. Open browser console (F12)
2. Navigate to a project calendar page
3. Check for these messages:
```
[RedmineCalendarSimple] Script loaded
[RedmineCalendarSimple] DOM ready
[RedmineCalendarSimple] Calendar found, initializing...
[RedmineCalendarSimple] Enhanced X calendar days
[RedmineCalendarSimple] Enhanced X issues
[RedmineCalendarSimple] Initialization complete
```

### Step 5: Test Functionality

Run in console:
```javascript
// Test 1: Check for plugin marker
$('#redmine-calendar-plugin-loaded').length  // Should be 1

// Test 2: Check for enhanced elements
$('.calendar-day-enhanced').length  // Should be > 0
$('.calendar-issue-enhanced').length  // Should be > 0

// Test 3: Run debug tests
RedmineCalendarDebug()
```

### Step 6: Manual Tests

1. **Double-click test**: Double-click on any date cell
   - Expected: Prompt to create issue

2. **Drag test**: Try dragging an issue
   - Expected: Issue becomes semi-transparent

3. **Right-click test**: Right-click on an issue
   - Expected: Context menu appears

4. **Drop test**: Drag issue to another date
   - Expected: Alert showing target date

## If Still Not Working

### Option 1: Check for JavaScript Errors

In browser console, look for:
- Red errors (exceptions)
- Failed asset loads (404 errors)
- Missing functions

### Option 2: Verify HTML Structure

Run in console:
```javascriptn// Check calendar structure
$('.calendar').html()

// Check a day cell
$('.calendar td').first().html()

// Check if issues exist
$('.calendar .issue').length
```

### Option 3: Check Plugin Status

```bash
cd /path/to/redmine
bundle exec rails runner "puts Redmine::Plugin.registered_plugins.keys"
```

Should include `:redmine_calendar`

### Option 4: Use Minimal Test

Create a test file in `plugins/redmine_calendar/test.html`:
```html
<h1>Calendar Test</h1>
<div class="calendar">
  <table>
    <tr>
      <td class="calendar-day-enhanced" data-date="2026-02-03">
        <p class="day-number">3</p>
        <div class="issue calendar-issue-enhanced" id="issue-123" draggable="true">
          Test Issue
        </div>
      </td>
    </tr>
  </table>
</div>
```

Then access it and check if features work.

## Final Steps

If everything works:
1. Replace `redmine_calendar_simple.js` with full `redmine_calendar.js`
2. Update hooks to load the full version
3. Test all features (create, drag, context menu, edit created on)
4. Verify history and activity logging

## Contact Information

If still having issues, provide:
1. Output of `./verify_plugin.sh`
2. Browser console logs
3. Redmine log entries (with [RedmineCalendar] tags)
4. Redmine version and environment
5. Browser version