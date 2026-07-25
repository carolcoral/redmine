# Redmine Calendar Enhancement Plugin

A calendar enhancement plugin for Redmine 6.1+ with intuitive interaction features.

## Features

### 1. Double-click to Create Issues
- Double-click any date in the calendar view
- Quick dialog to create new issues
- Set subject, start date, due date, and assignee

### 2. Drag-and-drop Date Modification
- Drag issues to different dates
- Automatically updates issue start date
- Real-time save with history tracking

### 3. Right-click Context Menu
- Right-click issues in calendar
- Quickly change assignee
- Delete issues (requires delete permission)

### 4. Activity Logging
- All operations automatically logged to activity stream
- Detailed records for create, update, and delete actions

### 5. Issue History
- All non-delete operations recorded in issue history
- Includes before/after value comparison
- Easy tracking of issue changes

## Installation

1. Download plugin to Redmine plugins directory
```bash
cd /path/to/redmine/plugins
git clone https://github.com/yourusername/redmine_calendar.git redmine_calendar
```

2. Install dependencies
```bash
cd /path/to/redmine
bundle install
```

3. Run database migrations (if needed)
```bash
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

4. Restart Redmine
```bash
touch tmp/restart.txt  # For Passenger
# Or restart your application server
```

5. Configure plugin permissions
- Go to Administration -> Roles and Permissions
- Assign "Edit calendar issues" permission to roles

## Configuration

In Administration -> Plugins -> Calendar Enhancement, you can configure:

- **Show issue context menu**: Enable/disable right-click menu
- **Enable drag and drop**: Enable/disable drag-and-drop functionality
- **Enable double-click to create issue**: Enable/disable double-click creation

## Usage

### Creating Issues
1. Navigate to project calendar view
2. Double-click the desired date
3. Fill in issue details and save

### Modifying Dates
1. Click and hold the issue to move
2. Drag to target date
3. Release mouse to complete

### Changing Assignee
1. Right-click on the issue
2. Select "Change assignee"
3. Choose new assignee and confirm

### Deleting Issues
1. Right-click on the issue
2. Select "Delete"
3. Confirm deletion

## Permissions

- **View calendar**: View calendar permission (built-in Redmine)
- **Edit calendar issues**: Permission to create, modify, and delete (plugin added)

## Requirements

- Redmine 6.1.0 or higher
- Ruby 3.0+
- Rails 6.1+

## Browser Compatibility

- Chrome 80+
- Firefox 75+
- Safari 13+
- Edge 80+

## License

MIT License

## Contributing

Issues and Pull Requests are welcome!

## Changelog

### v1.0.0
- Initial release
- Double-click to create issues
- Drag-and-drop date modification
- Right-click menu for assignee and delete
- Full activity and history tracking