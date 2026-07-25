// Debug helper for Redmine Calendar Plugin
(function($) {
  'use strict';

  window.RedmineCalendarDebug = {
    runTests: function() {
      console.log('=== Redmine Calendar Plugin Debug Tests ===');
      
      var results = [];
      
      // Test 1: Check if calendar data is available
      var hasData = $('#redmine-calendar-data').length > 0;
      results.push({
        test: 'Calendar data element exists',
        passed: hasData,
        data: hasData ? $('#redmine-calendar-data').data() : null
      });
      
      // Test 2: Check if calendar days have data-date attribute
      var calendarDays = $('.calendar-day');
      results.push({
        test: 'Calendar days with data-date attribute',
        passed: calendarDays.length > 0,
        count: calendarDays.length,
        sample: calendarDays.length > 0 ? calendarDays.first().data('date') : null
      });
      
      // Test 3: Check if issues are enhanced
      var issues = $('.calendar-issue');
      results.push({
        test: 'Enhanced calendar issues',
        passed: issues.length > 0,
        count: issues.length,
        sample: issues.length > 0 ? {
          id: issues.first().data('issue-id'),
          draggable: issues.first().attr('draggable')
        } : null
      });
      
      // Test 4: Check for JavaScript errors
      var hasJquery = typeof $ !== 'undefined';
      var hasRedmineCalendar = typeof RedmineCalendar !== 'undefined';
      results.push({
        test: 'JavaScript libraries loaded',
        passed: hasJquery && hasRedmineCalendar,
        details: {
          jQuery: hasJquery,
          RedmineCalendar: hasRedmineCalendar
        }
      });
      
      // Print results
      console.log('Test Results:');
      results.forEach(function(result, index) {
        var status = result.passed ? '✓ PASS' : '✗ FAIL';
        console.log((index + 1) + '. ' + result.test + ': ' + status);
        if (result.data) console.log('   Data:', result.data);
        if (result.count) console.log('   Count:', result.count);
        if (result.sample) console.log('   Sample:', result.sample);
        if (result.details) console.log('   Details:', result.details);
      });
      
      console.log('=== End Debug Tests ===');
      return results;
    },
    
    // Manually trigger double-click on a specific date
    testDoubleClick: function(date) {
      console.log('Testing double-click on date:', date);
      var $day = $('.calendar-day[data-date="' + date + '"]');
      if ($day.length) {
        console.log('Found day cell:', $day);
        $day.trigger('dblclick');
        return true;
      } else {
        console.error('Day cell not found for date:', date);
        return false;
      }
    },
    
    // Check event listeners
    checkEventListeners: function() {
      console.log('Checking event listeners...');
      
      var events = $._data(document, 'events');
      if (events) {
        console.log('Document event listeners:');
        Object.keys(events).forEach(function(eventType) {
          console.log('  - ' + eventType + ': ' + events[eventType].length + ' listeners');
        });
      } else {
        console.log('No event listeners found on document');
      }
    }
  };

  console.log('Redmine Calendar Debug utilities loaded. Use RedmineCalendarDebug.runTests() to run tests.');

})(jQuery);

// Auto-run tests when page loads
$(document).ready(function() {
  setTimeout(function() {
    console.log('Auto-running Redmine Calendar debug tests...');
    window.RedmineCalendarDebug.runTests();
  }, 1000);
});