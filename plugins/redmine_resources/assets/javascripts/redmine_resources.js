/*
This file is a part of Redmine Resources (redmine_resources) plugin,
resource allocation and management for Redmine

Copyright (C) 2011-2025 RedmineUP
http://www.redmineup.com/

This file is covering by RedmineUP Proprietary Use License as any images,
cascading stylesheets, manuals and JavaScript files in any extensions
produced and/or distributed by redmineup.com. These files are copyrighted by
redmineup.com (RedmineUP) and cannot be redistributed in any form
without prior consent from redmineup.com (RedmineUP)

*/
function addParamsToURL(url, data) {
  if (!$.isEmptyObject(data)) {
    url += (url.indexOf('?') >= 0 ? '&' : '?') + $.param(data);
  }

  return url;
};

function addEditableBarsOnClickListener() {
  $('.resource-planning-chart #gantt_area').on('click', '.booking-bar', function () {
    if ($(this).hasClass('no-click')) {
      $(this).removeClass('no-click')
    } else {
      var editUrl = this.getAttribute('edit_url');
      if (editUrl) {
        $.ajax(addParamsToURL(editUrl))
      }
    }
  });
};

function initializeResizableSubjectsColumn() {
  $('td.gantt_subjects_column').resizable({
    alsoResize: '.gantt_subjects_container, .gantt_subjects_container>.gantt_hdr',
    minWidth: 100,
    handles: 'e',
  });

  if(isMobile()) {
    $('td.gantt_subjects_column').resizable('disable');
  } else{
    $('td.gantt_subjects_column').resizable('enable');
  };
};

function drawSelectedColumns(){
  if ($("#draw_selected_columns").prop('checked')) {
    if(isMobile()) {
      $('td.gantt_selected_column').each(function(i) {
        $(this).hide();
      });
    }else{
      if ($('td.gantt_selected_column').length > 0) {
        $('.gantt_subjects_container').addClass('draw_selected_columns');

        $('td.gantt_selected_column').each(function() {
          $(this).show();
          var column_name = $(this).attr('id');
          $(this).resizable({
            alsoResize: '.gantt_' + column_name + '_container, .gantt_' + column_name + '_container > .gantt_hdr',
            minWidth: 20,
            handles: "e",
            create: function() {
              $(".ui-resizable-e").css("cursor","ew-resize");
            }
          }).on('resize', function (e) {
              e.stopPropagation();
          });
        });
      }
    }
  }else{
    $('td.gantt_selected_column').each(function (i) {
      $(this).hide();
      $('.gantt_subjects_container').removeClass('draw_selected_columns');
    });
  }
}

function updateUserBlock(userId, subjects, lines, columns, blockHeight) {
  var $userSubjectsBlock = $('.resource-planning-chart div.resource-subjects [group_id=' + userId + ']');
  var $resourceColumnsContainer = $('.resource-planning-chart .resource-columns');

  if ($userSubjectsBlock.length === 1) {
    resizeChartTable(blockHeight, $userSubjectsBlock.height())
    $userSubjectsBlock.replaceWith(subjects);
    $('.resource-planning-chart div.resource-lines [group_id=' + userId + ']').replaceWith(lines)

    for (const columnId in columns) {
      var $userColumnBlock = $resourceColumnsContainer.find('[id=' + columnId + '_user_' + userId + ']');

      if ($userColumnBlock.length === 1) {
        $userColumnBlock.replaceWith(columns[columnId]);
      } else {
        $resourceColumnsContainer.append(columns[columnId]);
      }
    }

  } else {
    resizeChartTable(blockHeight)
    $('.resource-planning-chart .gantt_subjects_column .resource-subjects').append(subjects);
    $('.resource-planning-chart #gantt_area .resource-lines').append(lines);

    for (const columnId in columns) {
      $resourceColumnsContainer.append(columns[columnId]);
    }

  }
};

function resizeChartTable(blockHeight, elementHeight = 0) {
  if (blockHeight === 0) return

  var $subjectContainer = $('.gantt_subjects_container');
  var $selectedColumnsContainer = $('.gantt_selected_column_container');
  var $bookingsContainer = $('#gantt_area');
  var $subjectColumn = $('.subject_column');
  var $bookingColumns = $('.bookings-column');
  var $serviceColumns = $('.service-column');

  var deltaHeight = blockHeight - elementHeight
  var subjectContainerHeight = $subjectContainer.height();
  var bookingsHeight = $bookingColumns.first().height() + deltaHeight;
  var serviceHeight = $serviceColumns.first().height() + deltaHeight;

  $subjectContainer.height(subjectContainerHeight + deltaHeight);
  $bookingsContainer.height(subjectContainerHeight + deltaHeight);
  $selectedColumnsContainer.height(subjectContainerHeight + deltaHeight);
  $subjectColumn.height($subjectColumn.height() + deltaHeight);

  $.each($bookingColumns, function(index, column) {
    $(column).height(bookingsHeight)
  });

  $.each($serviceColumns, function(index, column) {
    $(column).height(serviceHeight)
  });
}

function renderFlashMessages(html) {
  var $content = $('#content');
  $content.children('[id^="flash_"]').remove();
  $content.prepend(html);
};

function updateResourceBookingFrom(url) {
  $.ajax({
    url: url,
    data: $('#resource-booking-form').serialize()
  });
};

function formatStateWithLineThrough(opt) {
  if (opt.line_through) {
    return $('<span class="crossed-out-option">' + opt.text + '</span>');
  } else {
    return $('<span>' + opt.text + '</span>');
  }
};

function toggleAllUserResourceBookingsGroups() {
  var $groups = $('.user-resource-bookings');
  var open = !$groups.first().hasClass('open');
  var icon = open ? 'angle-down' : 'angle-right';

  $groups.toggleClass('open', open).each(function () {
    updateSVGIcon($(this).find('.expander')[0], icon);
  });
};

function toggleBlockGroup(groupName, value) {
  $('.' + groupName).hide();
  $('.' + groupName + '.' + value).show();
};

function toggleBookingRowGroup(el) {
  var tr = $(el).parents('tr').first();
  var n = tr.next();
  tr.toggleClass('open');
  $(el).toggleClass('icon-expended icon-collapsed');

  if (tr.hasClass('open')) {
    updateSVGIcon(el, 'angle-down');
  } else {
    updateSVGIcon(el, 'angle-right');
  }

  while (n.length && !n.hasClass('group')) {
    if (n.hasClass('booking-data')) {
      n.toggle();
    }
    n = n.next('tr');
  }
};

function toggleAllBookingRowGroups(el) {
  var tr = $(el).parents('tr').first();
  if (tr.hasClass('open')) {
    collapseAllBookingRowGroups(el);
  } else {
    expandAllRowGroups(el);
  }
};

function collapseAllBookingRowGroups(el) {
  var tbody = $(el).parents('tbody').first();
  tbody.children('tr').each(function(index) {
    if ($(this).hasClass('group')) {
      $(this).removeClass('open');
      var expander = $(this).find('.expander');
      expander.switchClass('icon-expended', 'icon-collapsed');
      updateSVGIcon(expander[0], 'angle-right');
    } else {
      if ($(this).hasClass('booking-data')) {
        $(this).hide();
      }
    }
  });
};

function addEditableBookingCardOnClickListener() {
  $('.utilization-report').on('click', '.small-booking-card', function () {
    if ($(this).hasClass('no-click')) {
      $(this).removeClass('no-click')
    } else {
      var editUrl = this.getAttribute('edit_url');
      if (editUrl) {
        $.ajax(addParamsToURL(editUrl))
      }
    }
  });
};
