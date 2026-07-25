// Redmine Calendar Plugin - Simple Version
// This is a minimal version to ensure basic functionality works

console.log('[RedmineCalendarSimple] Script loaded');

(function($) {
  'use strict';

  // Wait for DOM to be ready
  $(document).ready(function() {
    console.log('[RedmineCalendarSimple] DOM ready');
    
    // Check if we're on a calendar page
    if ($('.calendar').length === 0) {
      console.log('[RedmineCalendarSimple] No calendar found on this page');
      return;
    }
    
    console.log('[RedmineCalendarSimple] Calendar found, initializing...');
    
    // Get project ID from URL
    var projectId = getProjectIdFromUrl();
    console.log('[RedmineCalendarSimple] Project ID:', projectId);
    
    // Enhance calendar days
    enhanceCalendarDays();
    
    // Enhance issues
    enhanceIssues();
    
    // Setup event handlers
    setupDoubleClick();
    setupDragAndDrop();
    setupContextMenu();
    
    console.log('[RedmineCalendarSimple] Initialization complete');
  });

  function getProjectIdFromUrl() {
    var match = window.location.pathname.match(/\/projects\/([^\/]+)/);
    return match ? match[1] : null;
  }

  function enhanceCalendarDays() {
    console.log('[RedmineCalendarSimple] Enhancing calendar days...');
    
    var count = 0;
    
    // Find all calendar day cells
    $('.calendar td').each(function() {
      var $td = $(this);
      
      // Skip if already enhanced or if it's a header
      if ($td.hasClass('calendar-day-enhanced') || $td.hasClass('week-number')) return;
      
      // Try to extract date from link
      var $link = $td.find('a[href*="from="]');
      if ($link.length) {
        var href = $link.attr('href');
        var match = href.match(/from=([0-9]{4}-[0-9]{2}-[0-9]{2})/);
        
        if (match) {
          var date = match[1];
          $td.addClass('calendar-day calendar-day-enhanced');
          $td.attr('data-date', date);
          $td.css('cursor', 'pointer');
          $td.attr('title', 'Double-click to create issue on ' + date);
          count++;
        }
      }
    });
    
    console.log('[RedmineCalendarSimple] Enhanced', count, 'calendar days');
  }

  function enhanceIssues() {
    console.log('[RedmineCalendarSimple] Enhancing issues...');
    
    var count = 0;
    
    $('.calendar .issue').each(function() {
      var $issue = $(this);
      
      if ($issue.hasClass('calendar-issue-enhanced')) return;
      
      var issueId = $issue.attr('id');
      if (issueId) {
        issueId = issueId.replace('issue-', '');
        
        $issue.addClass('calendar-issue calendar-issue-enhanced');
        $issue.attr('data-issue-id', issueId);
        $issue.attr('draggable', 'true');
        $issue.css('cursor', 'move');
        
        // Add context menu
        var $menu = $('<div class="calendar-issue-context-menu" style="display: none; position: absolute; background: white; border: 1px solid #ccc; z-index: 1000;">');
        $menu.append('<div style="padding: 8px; cursor: pointer;" data-action="edit">编辑</div>');
        $menu.append('<div style="padding: 8px; cursor: pointer;" data-action="delete">删除</div>');
        
        $issue.append($menu);
        count++;
      }
    });
    
    console.log('[RedmineCalendarSimple] Enhanced', count, 'issues');
  }

  function setupDoubleClick() {
    console.log('[RedmineCalendarSimple] Setting up double-click...');
    
    $(document).on('dblclick', '.calendar-day', function(e) {
      e.preventDefault();
      e.stopPropagation();
      
      var $day = $(this);
      var date = $day.data('date');
      var projectId = getProjectIdFromUrl();
      
      console.log('[RedmineCalendarSimple] Double-click on date:', date);
      
      if (!date) {
        alert('Error: Could not determine date');
        return;
      }
      
      var subject = prompt('Create new issue on ' + date + ':\n\nEnter issue subject:');
      
      if (subject && subject.trim()) {
        alert('Would create issue: "' + subject + '"\nDate: ' + date + '\nProject: ' + (projectId || 'Unknown'));
        // TODO: Implement actual creation via AJAX
      }
    });
  }

  function setupDragAndDrop() {
    console.log('[RedmineCalendarSimple] Setting up drag and drop...');
    
    $(document).on('dragstart', '.calendar-issue', function(e) {
      var $issue = $(this);
      var issueId = $issue.data('issue-id');
      
      console.log('[RedmineCalendarSimple] Drag start:', issueId);
      
      e.originalEvent.dataTransfer.setData('text/plain', issueId);
      $issue.css('opacity', '0.5');
    });
    
    $(document).on('dragend', '.calendar-issue', function(e) {
      $(this).css('opacity', '1');
    });
    
    $(document).on('dragover', '.calendar-day', function(e) {
      e.preventDefault();
      $(this).css('background-color', '#e3f2fd');
    });
    
    $(document).on('dragleave', '.calendar-day', function(e) {
      $(this).css('background-color', '');
    });
    
    $(document).on('drop', '.calendar-day', function(e) {
      e.preventDefault();
      e.stopPropagation();
      
      var $day = $(this);
      var issueId = e.originalEvent.dataTransfer.getData('text/plain');
      var newDate = $day.data('date');
      
      $day.css('background-color', '');
      
      console.log('[RedmineCalendarSimple] Drop:', issueId, 'on date:', newDate);
      
      if (issueId && newDate) {
        alert('Would move issue ' + issueId + ' to date ' + newDate);
        // TODO: Implement actual move via AJAX
      }
    });
  }

  function setupContextMenu() {
    console.log('[RedmineCalendarSimple] Setting up context menu...');
    
    $(document).on('contextmenu', '.calendar-issue', function(e) {
      e.preventDefault();
      e.stopPropagation();
      
      var $issue = $(this);
      var $menu = $issue.find('.calendar-issue-context-menu');
      
      $('.calendar-issue-context-menu').hide();
      
      $menu.css({
        left: e.pageX,
        top: e.pageY
      }).show();
      
      return false;
    });
    
    $(document).on('click', function() {
      $('.calendar-issue-context-menu').hide();
    });
    
    $(document).on('click', '.calendar-issue-context-menu [data-action]', function(e) {
      e.stopPropagation();
      
      var action = $(this).data('action');
      var $issue = $(this).closest('.calendar-issue');
      var issueId = $issue.data('issue-id');
      
      console.log('[RedmineCalendarSimple] Context menu action:', action, 'issue:', issueId);
      
      $('.calendar-issue-context-menu').hide();
      
      if (action === 'edit') {
        alert('Edit issue ' + issueId);
      } else if (action === 'delete') {
        if (confirm('Delete issue ' + issueId + '?')) {
          alert('Would delete issue ' + issueId);
          // TODO: Implement actual deletion
        }
      }
    });
  }

  // Global debug function
  window.RedmineCalendarDebug = function() {
    console.log('=== Redmine Calendar Debug ===');
    console.log('Calendar days:', $('.calendar-day').length);
    console.log('Enhanced issues:', $('.calendar-issue-enhanced').length);
    console.log('Project ID:', getProjectIdFromUrl());
  };

})(jQuery);

console.log('[RedmineCalendarSimple] Script execution complete');