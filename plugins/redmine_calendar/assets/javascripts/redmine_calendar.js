(function($) {
  'use strict';

  var RedmineCalendar = {
    init: function() {
      this.setupDoubleClick();
      this.setupDragAndDrop();
      this.setupContextMenu();
      this.setupEventHandlers();
    },

    setupDoubleClick: function() {
      var self = this;
      console.log('Setting up double-click handler');
      
      // Use delegated event handler on document for better reliability
      $(document).on('dblclick', '.calendar-day', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        console.log('Double-click detected on calendar day');
        
        var $day = $(this);
        var date = $day.data('date');
        var projectId = self.getProjectId();
        
        console.log('Date:', date, 'Project ID:', projectId);
        
        if (!date) {
          console.warn('No date found on calendar day');
          return;
        }
        
        if (!projectId) {
          console.warn('No project ID found');
        }
        
        self.showCreateIssueDialog(date, projectId);
      });
    },

    setupDragAndDrop: function() {
      var self = this;
      console.log('Setting up drag and drop handlers');
      
      $(document).on('dragstart', '.calendar-issue', function(e) {
        var $issue = $(this);
        var issueId = $issue.data('issue-id');
        
        console.log('Drag started on issue:', issueId);
        
        e.originalEvent.dataTransfer.setData('text/plain', issueId);
        e.originalEvent.dataTransfer.effectAllowed = 'move';
        $issue.addClass('dragging');
      });
      
      $(document).on('dragend', '.calendar-issue', function(e) {
        console.log('Drag ended');
        $(this).removeClass('dragging');
        $('.calendar-day').removeClass('drag-over');
      });
      
      $(document).on('dragenter', '.calendar-day', function(e) {
        e.preventDefault();
        $(this).addClass('drag-over');
      });
      
      $(document).on('dragover', '.calendar-day', function(e) {
        e.preventDefault();
        e.originalEvent.dataTransfer.dropEffect = 'move';
        $(this).addClass('drag-over');
      });
      
      $(document).on('dragleave', '.calendar-day', function(e) {
        if (!$(this).has(e.relatedTarget).length) {
          $(this).removeClass('drag-over');
        }
      });
      
      $(document).on('drop', '.calendar-day', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        var $day = $(this);
        $day.removeClass('drag-over');
        
        var issueId = e.originalEvent.dataTransfer.getData('text/plain');
        var newDate = $day.data('date');
        
        console.log('Drop event:', 'Issue ID:', issueId, 'New Date:', newDate);
        
        if (!issueId) {
          console.warn('No issue ID in drop event');
          return;
        }
        
        if (!newDate) {
          console.warn('No date on drop target');
          return;
        }
        
        self.updateIssueDate(issueId, newDate);
      });
    },

    setupContextMenu: function() {
      var self = this;
      
      $(document).on('contextmenu', '.calendar-issue', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        var $issue = $(this);
        var $menu = $issue.find('.calendar-issue-context-menu');
        
        $('.calendar-issue-context-menu').hide();
        
        $menu.css({
          position: 'absolute',
          left: e.pageX,
          top: e.pageY,
          zIndex: 1000
        }).show();
        
        $issue.addClass('context-menu-open');
      });
      
      $(document).on('click', function(e) {
        if (!$(e.target).closest('.calendar-issue-context-menu').length && 
            !$(e.target).closest('.calendar-issue').length) {
          $('.calendar-issue-context-menu').hide();
          $('.calendar-issue').removeClass('context-menu-open');
        }
      });
      
      $(document).on('click', '.context-menu-item[data-action="edit_assigned_to"]', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        var $issue = $(this).closest('.calendar-issue');
        var issueId = $issue.data('issue-id');
        
        self.showChangeAssigneeDialog(issueId);
        $('.calendar-issue-context-menu').hide();
        $('.calendar-issue').removeClass('context-menu-open');
      });
      
      $(document).on('click', '.context-menu-item[data-action="edit_created_on"]', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        var $issue = $(this).closest('.calendar-issue');
        var issueId = $issue.data('issue-id');
        
        self.showChangeCreatedOnDialog(issueId);
        $('.calendar-issue-context-menu').hide();
        $('.calendar-issue').removeClass('context-menu-open');
      });
      
      $(document).on('click', '.context-menu-item[data-action="delete_issue"]', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        var $issue = $(this).closest('.calendar-issue');
        var issueId = $issue.data('issue-id');
        
        if (confirm(self.getTranslation('confirm_delete'))) {
          self.deleteIssue(issueId, $issue);
        }
        
        $('.calendar-issue-context-menu').hide();
        $('.calendar-issue').removeClass('context-menu-open');
      });
    },

    setupEventHandlers: function() {
      var self = this;
      
      $(document).on('mouseenter', '.calendar-issue', function() {
        $(this).addClass('hover');
      });
      
      $(document).on('mouseleave', '.calendar-issue', function() {
        $(this).removeClass('hover');
      });
    },

    showCreateIssueDialog: function(date, projectId) {
      var self = this;
      var translations = self.getTranslations();
      
      console.log('Showing create issue dialog for date:', date, 'project:', projectId);
      
      var dialogHtml = '<div id="calendar-issue-dialog" class="calendar-dialog" style="display: none;">' +
        '<h3>' + (translations.new_issue || 'New Issue') + '</h3>' +
        '<div class="form-group">' +
          '<label>' + (this.getLabel('field_subject') || 'Subject') + '</label>' +
          '<input type="text" id="issue-subject" class="form-control" style="width: 100%; padding: 8px;" />' +
        '</div>' +
        '<div class="form-group">' +
          '<label>' + (this.getLabel('field_start_date') || 'Start date') + '</label>' +
          '<input type="text" id="issue-start-date" class="form-control" value="' + date + '" readonly style="width: 100%; padding: 8px; background: #f5f5f5;" />' +
        '</div>' +
        '<div class="form-group">' +
          '<label>' + (this.getLabel('field_due_date') || 'Due date') + '</label>' +
          '<input type="text" id="issue-due-date" class="form-control" style="width: 100%; padding: 8px;" placeholder="YYYY-MM-DD" />' +
        '</div>' +
        '<div class="form-group">' +
          '<label>' + (this.getLabel('field_assigned_to') || 'Assignee') + '</label>' +
          '<select id="issue-assigned-to" class="form-control" style="width: 100%; padding: 8px;">' +
            this.getAssigneeOptionsHtml() +
          '</select>' +
        '</div>' +
        '<div class="form-actions" style="margin-top: 20px; text-align: right;">' +
          '<button type="button" id="cancel-issue-btn" class="btn btn-default" style="margin-right: 10px; padding: 8px 16px;">' + (this.getLabel('button_cancel') || 'Cancel') + '</button>' +
          '<button type="button" id="create-issue-btn" class="btn btn-primary" style="padding: 8px 16px; background: #2196F3; color: white; border: none;">' + (this.getLabel('button_create') || 'Create') + '</button>' +
        '</div>' +
      '</div>';
      
      $('body').append(dialogHtml);
      
      // Show dialog
      $('#calendar-issue-dialog').show().css({
        'position': 'fixed',
        'top': '50%',
        'left': '50%',
        'transform': 'translate(-50%, -50%)',
        'background': 'white',
        'padding': '20px',
        'border-radius': '8px',
        'box-shadow': '0 4px 16px rgba(0,0,0,0.2)',
        'z-index': '9999',
        'min-width': '400px'
      });
      
      // Add overlay
      var $overlay = $('<div id="calendar-dialog-overlay" style="position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 9998;"></div>');
      $('body').append($overlay);
      
      // Handle create button
      $('#create-issue-btn').click(function() {
        self.createIssue(date, projectId);
      });
      
      // Handle cancel button
      $('#cancel-issue-btn').click(function() {
        $('#calendar-issue-dialog').remove();
        $('#calendar-dialog-overlay').remove();
      });
      
      // Handle overlay click
      $overlay.click(function() {
        $('#calendar-issue-dialog').remove();
        $('#calendar-dialog-overlay').remove();
      });
    },

    showChangeAssigneeDialog: function(issueId) {
      var self = this;
      var translations = self.getTranslations();
      
      var dialogHtml = '<div id="calendar-assignee-dialog" class="calendar-dialog">' +
        '<h3>' + translations.change_assigned_to + '</h3>' +
        '<div class="form-group">' +
          '<label>' + this.getLabel('field_assigned_to') + '</label>' +
          '<select id="new-assigned-to" class="form-control">' +
            this.getAssigneeOptionsHtml() +
          '</select>' +
        '</div>' +
        '<div class="form-actions">' +
          '<button type="button" id="update-assignee-btn" class="btn btn-primary">' + this.getLabel('button_apply') + '</button>' +
          '<button type="button" id="cancel-assignee-btn" class="btn btn-default">' + this.getLabel('button_cancel') + '</button>' +
        '</div>' +
      '</div>';
      
      $('body').append(dialogHtml);
      $('#calendar-assignee-dialog').modal();
      
      $('#update-assignee-btn').click(function() {
        var assignedToId = $('#new-assigned-to').val();
        self.updateIssueAssignee(issueId, assignedToId);
      });
      
      $('#cancel-assignee-btn').click(function() {
        $('#calendar-assignee-dialog').modal('hide');
        $('#calendar-assignee-dialog').remove();
      });
    },

    createIssue: function(date, projectId) {
      var self = this;
      var subject = $('#issue-subject').val();
      var startDate = $('#issue-start-date').val();
      var dueDate = $('#issue-due-date').val();
      var assignedToId = $('#issue-assigned-to').val();
      
      console.log('Creating issue:', { subject: subject, startDate: startDate, dueDate: dueDate, assignedToId: assignedToId });
      
      if (!subject || !subject.trim()) {
        alert('Subject cannot be blank');
        return;
      }
      
      var data = {
        project_id: projectId,
        subject: subject,
        start_date: startDate
      };
      
      if (dueDate && dueDate.trim()) data.due_date = dueDate;
      if (assignedToId && assignedToId.trim()) data.assigned_to_id = assignedToId;
      
      console.log('Sending AJAX request to:', self.getCreateIssueUrl(), 'with data:', data);
      
      $.ajax({
        url: self.getCreateIssueUrl(),
        type: 'POST',
        data: data,
        dataType: 'json',
        success: function(response) {
          console.log('Create issue response:', response);
          
          if (response.success) {
            $('#calendar-issue-dialog').remove();
            $('#calendar-dialog-overlay').remove();
            
            // Show success message
            alert('Issue created successfully: ' + response.issue.subject);
            
            // Optionally refresh the page or add the issue to the calendar
            if (confirm('Issue created! Would you like to refresh the calendar to see it?')) {
              window.location.reload();
            }
          } else {
            alert('Failed to create issue: ' + (response.errors || []).join(', '));
          }
        },
        error: function(xhr, status, error) {
          console.error('AJAX error:', status, error, xhr.responseText);
          alert('Failed to create issue: ' + (xhr.responseText || error));
        }
      });
    },

    updateIssueDate: function(issueId, newDate) {
      var self = this;
      
      $.ajax({
        url: self.getUpdateIssueDateUrl(issueId),
        type: 'PUT',
        data: {
          start_date: newDate
        },
        dataType: 'json',
        success: function(response) {
          if (response.success) {
            self.moveIssueToDate(issueId, newDate);
          } else {
            alert(self.getLabel('notice_failed_to_save_issues') + ': ' + (response.errors || []).join(', '));
          }
        },
        error: function() {
          alert(self.getLabel('notice_failed_to_save_issues'));
        }
      });
    },

    updateIssueAssignee: function(issueId, assignedToId) {
      var self = this;
      
      $.ajax({
        url: self.getUpdateAssignedToUrl(issueId),
        type: 'PUT',
        data: {
          assigned_to_id: assignedToId
        },
        dataType: 'json',
        success: function(response) {
          if (response.success) {
            $('#calendar-assignee-dialog').remove();
            $('#calendar-dialog-overlay').remove();
            
            alert('Assignee updated successfully!');
            self.updateIssueAssigneeInCalendar(issueId, response.issue.assigned_to_name);
          } else {
            alert(self.getLabel('notice_failed_to_save_issues') + ': ' + (response.errors || [response.error]).join(', '));
          }
        },
        error: function() {
          alert(self.getLabel('notice_failed_to_save_issues'));
        }
      });
    },
    
    showChangeCreatedOnDialog: function(issueId) {
      var self = this;
      var translations = self.getTranslations();
      
      console.log('Showing change created_on dialog for issue:', issueId);
      
      var dialogHtml = '<div id="calendar-created-on-dialog" class="calendar-dialog" style="display: none;">' +
        '<h3>Change Created On</h3>' +
        '<div class="form-group">' +
          '<label>Created on</label>' +
          '<input type="text" id="issue-created-on" class="form-control" style="width: 100%; padding: 8px;" placeholder="YYYY-MM-DD" />' +
        '</div>' +
        '<div class="form-actions" style="margin-top: 20px; text-align: right;">' +
          '<button type="button" id="cancel-created-on-btn" class="btn btn-default" style="margin-right: 10px; padding: 8px 16px;">Cancel</button>' +
          '<button type="button" id="update-created-on-btn" class="btn btn-primary" style="padding: 8px 16px; background: #2196F3; color: white; border: none;">Update</button>' +
        '</div>' +
      '</div>';
      
      $('body').append(dialogHtml);
      
      // Show dialog
      $('#calendar-created-on-dialog').show().css({
        'position': 'fixed',
        'top': '50%',
        'left': '50%',
        'transform': 'translate(-50%, -50%)',
        'background': 'white',
        'padding': '20px',
        'border-radius': '8px',
        'box-shadow': '0 4px 16px rgba(0,0,0,0.2)',
        'z-index': '9999',
        'min-width': '350px'
      });
      
      // Add overlay
      var $overlay = $('<div id="calendar-dialog-overlay" style="position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 9998;"></div>');
      $('body').append($overlay);
      
      // Handle update button
      $('#update-created-on-btn').click(function() {
        var createdOn = $('#issue-created-on').val();
        self.updateIssueCreatedOn(issueId, createdOn);
      });
      
      // Handle cancel button
      $('#cancel-created-on-btn').click(function() {
        $('#calendar-created-on-dialog').remove();
        $('#calendar-dialog-overlay').remove();
      });
      
      // Handle overlay click
      $overlay.click(function() {
        $('#calendar-created-on-dialog').remove();
        $('#calendar-dialog-overlay').remove();
      });
    },
    
    updateIssueCreatedOn: function(issueId, createdOn) {
      var self = this;
      
      console.log('Updating created_on for issue', issueId, 'to', createdOn);
      
      if (!createdOn || !createdOn.trim()) {
        alert('Please enter a valid date');
        return;
      }
      
      // Validate date format
      var dateRegex = /^\d{4}-\d{2}-\d{2}$/;
      if (!dateRegex.test(createdOn)) {
        alert('Please enter date in YYYY-MM-DD format');
        return;
      }
      
      $.ajax({
        url: self.getUpdateCreatedOnUrl(issueId),
        type: 'PUT',
        data: {
          created_on: createdOn
        },
        dataType: 'json',
        success: function(response) {
          console.log('Update created_on response:', response);
          
          if (response.success) {
            $('#calendar-created-on-dialog').remove();
            $('#calendar-dialog-overlay').remove();
            
            alert('Created on date updated successfully!');
            
            // Optionally refresh the page
            if (confirm('Date updated! Would you like to refresh the calendar to see the change?')) {
              window.location.reload();
            }
          } else {
            alert('Failed to update created on date: ' + (response.errors || [response.error]).join(', '));
          }
        },
        error: function(xhr, status, error) {
          console.error('AJAX error:', status, error, xhr.responseText);
          alert('Failed to update created on date: ' + (xhr.responseText || error));
        }
      });
    },

    deleteIssue: function(issueId, $issueElement) {
      var self = this;
      
      $.ajax({
        url: self.getDeleteIssueUrl(issueId),
        type: 'DELETE',
        dataType: 'json',
        success: function(response) {
          if (response.success) {
            $issueElement.fadeOut(function() {
              $(this).remove();
            });
          } else {
            alert(self.getLabel('notice_failed_to_save_issues') + ': ' + (response.error || ''));
          }
        },
        error: function() {
          alert(self.getLabel('notice_failed_to_save_issues'));
        }
      });
    },

    addIssueToCalendar: function(issue) {
      var $day = $('.calendar-day[data-date="' + issue.start_date + '"]');
      if ($day.length) {
        var issueHtml = this.createIssueHtml(issue);
        $day.find('.calendar-issues').append(issueHtml);
        
        var $newIssue = $day.find('.calendar-issue[data-issue-id="' + issue.id + '"]');
        $newIssue.hide().fadeIn();
        
        this.setupDragAndDrop();
      }
    },

    moveIssueToDate: function(issueId, newDate) {
      var $issue = $('.calendar-issue[data-issue-id="' + issueId + '"]');
      var $newDay = $('.calendar-day[data-date="' + newDate + '"]');
      
      if ($issue.length && $newDay.length) {
        var $issuesContainer = $newDay.find('.calendar-issues');
        if (!$issuesContainer.length) {
          $newDay.append('<div class="calendar-issues"></div>');
          $issuesContainer = $newDay.find('.calendar-issues');
        }
        
        $issue.fadeOut(function() {
          $(this).appendTo($issuesContainer).fadeIn();
          $(this).data('start-date', newDate);
        });
      }
    },

    updateIssueAssigneeInCalendar: function(issueId, assignedToName) {
      var $issue = $('.calendar-issue[data-issue-id="' + issueId + '"]');
      if ($issue.length) {
        var $assigneeSpan = $issue.find('.issue-assignee');
        if ($assigneeSpan.length) {
          $assigneeSpan.text(assignedToName || '');
        }
      }
    },

    createIssueHtml: function(issue) {
      var html = '<div class="calendar-issue' + (issue.is_closed ? ' closed' : '') + '" ' +
        'data-issue-id="' + issue.id + '" ' +
        'data-start-date="' + issue.start_date + '" ' +
        'draggable="true">' +
        '<span class="issue-tracker">' + issue.tracker_name + '</span> ' +
        '<span class="issue-subject">' + issue.subject + '</span>';
      
      if (issue.assigned_to_name) {
        html += ' <span class="issue-assignee">(' + issue.assigned_to_name + ')</span>';
      }
      
      html += '</div>';
      
      return html;
    },

    getCreateIssueUrl: function() {
      var data = $('#redmine-calendar-data').data();
      return data.createIssueUrl;
    },

    getUpdateIssueDateUrl: function(issueId) {
      var data = $('#redmine-calendar-data').data();
      return data.updateIssueDateUrl.replace('ISSUE_ID', issueId);
    },

    getUpdateAssignedToUrl: function(issueId) {
      var data = $('#redmine-calendar-data').data();
      return data.updateAssignedToUrl.replace('ISSUE_ID', issueId);
    },

    getDeleteIssueUrl: function(issueId) {
      var data = $('#redmine-calendar-data').data();
      return data.deleteIssueUrl.replace('ISSUE_ID', issueId);
    },

    getUpdateCreatedOnUrl: function(issueId) {
      var data = $('#redmine-calendar-data').data();
      if (!data.updateCreatedOnUrl) {
        console.error('updateCreatedOnUrl not found in calendar data');
        return '';
      }
      return data.updateCreatedOnUrl.replace('ISSUE_ID', issueId);
    },

    getProjectId: function() {
      var data = $('#redmine-calendar-data').data();
      return data.projectId;
    },

    getTranslations: function() {
      var data = $('#redmine-calendar-data').data();
      return data.translations || {};
    },

    getTranslation: function(key) {
      var translations = this.getTranslations();
      return translations[key] || '';
    },

    getLabel: function(key) {
      if (typeof labels !== 'undefined' && labels[key]) {
        return labels[key];
      }
      return key;
    },

    getAssigneeOptionsHtml: function() {
      var data = $('#redmine-calendar-data').data();
      var options = data.assigneeOptions || [];
      var html = '';
      
      for (var i = 0; i < options.length; i++) {
        html += '<option value="' + options[i][1] + '">' + options[i][0] + '</option>';
      }
      
      return html;
    }
  };

  $(document).ready(function() {
    RedmineCalendar.init();
  });

  $(document).on('ajax:success', function() {
    setTimeout(function() {
      RedmineCalendar.setupDragAndDrop();
    }, 100);
  });

})(jQuery);