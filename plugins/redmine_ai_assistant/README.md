# Redmine AI Assistant

AI-powered intelligent assistant plugin for Redmine, providing floating chat widget, automated work report generation, and multi-provider AI support.

## Features

- **Floating Chat Widget**: A draggable AI chat bubble in the bottom-right corner of every page, supporting natural language conversations
- **Work Report Generation**: One-click generation of daily/weekly/monthly reports based on user activity data (time entries, issue assignments, status changes, comments, wiki updates)
- **Multi-Provider AI Support**: Supports multiple AI service providers with a unified interface, compatible with OpenAI-style APIs
- **Read-Only Guard Prompt**: Automatically restricts AI to analysis-only mode when business data is involved, preventing accidental or malicious data modification suggestions
- **Custom System Prompt**: Administrators can define system-level prompt constraints via plugin settings
- **Customizable Icon**: Supports custom floating icon images (PNG/JPG/GIF/APNG/SVG), with auto-play for animated formats
- **Conversation History**: Persistent chat history with configurable context window size
- **Smart Data Injection**: Automatically detects task/report-related queries and injects real Redmine issue data as context
- **Issue Hyperlinks**: All issue references in reports and chat are rendered as clickable links that navigate directly to the issue detail page
- **Version & Progress Tracking**: Reports include version grouping analysis, progress percentages, due date alerts, and overdue issue detection
- **Dynamic System Name**: Uses the actual application name from `Setting.app_title` instead of hardcoded "Redmine"

## Requirements

- Redmine >= 6.1.0
- Ruby >= 3.2.0
- At least one AI service provider (OpenAI-compatible API)

## Installation

1. Copy the plugin directory into `plugins/redmine_ai_assistant`

2. Run database migrations:

```bash
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

3. Restart Redmine

4. Go to **Administration** → **Plugins** → **Redmine AI Assistant** → **Configure** to enable the plugin

## Configuration

### Plugin Settings

Go to **Administration** → **Plugins** → **Redmine AI Assistant** → **Configure**:

| Setting | Default | Description |
|---|---|---|
| Enable AI Assistant | Off | Enables the floating chat widget for logged-in users |
| Default AI Provider | (None) | The default AI service provider for chat and reports |
| Enable Read-Only Guard Prompt | On | Restricts AI to analysis-only mode when business data is involved |
| Custom System Prompt | (Empty) | Custom prompt injected before every AI call to control behavior |
| Max History Messages | 20 | Number of previous messages to include in conversation context (1-50) |
| Report Timezone | (Empty) | Timezone for report period calculation |
| Custom Pet Image URL | (Empty) | Custom floating icon image URL (supports PNG/JPG/GIF/APNG/WebP/SVG) |
| Icon Size | 60 | Floating button size in pixels (40-120) |

### AI Service Providers

Go to **Administration** → **AI Service Providers** to configure AI backends.

**Provider Types**:
- `tdp`: TDP platform integrated provider
- `custom`: Any OpenAI-compatible API (e.g., OpenAI, Ollama, vLLM, local LLM)

**Required Fields**:
- **Name**: Display name
- **Slug**: Unique identifier (lowercase letters, digits, hyphens, underscores)
- **Provider Type**: `tdp` or `custom`
- **API URL**: Full base URL (e.g., `https://api.openai.com/v1`)
- **API Key**: Authentication key (encrypted at rest)
- **Default Model**: Model name (e.g., `gpt-4o-mini`)

**Optional Fields**:
- **Available Models**: JSON array of model names — use the "Auto Fetch" button to retrieve from the API
- **Extra Settings**: JSON object for provider-specific parameters (e.g., top_p, frequency_penalty)

### Permissions

Three permissions control access:

| Permission | Access | Description |
|---|---|---|
| Manage AI Providers | Admin only | CRUD and enable/disable AI providers |
| Use AI Chat | Logged-in users | Access the floating chat widget |
| Generate AI Reports | Logged-in users | Generate work reports |

## Usage

### AI Chat

1. Click the floating icon in the bottom-right corner to open the chat panel
2. Type questions about your projects, tasks, or time entries
3. The assistant will automatically pull relevant Redmine data when you ask task-related questions
4. Use the quick-action buttons for one-click task summary or recent activity

**Trigger keywords** (at least 2 needed to trigger data injection): task, issue, status, priority, progress, version, due date, overdue, report, summary, today, week, month, 任务, 项目, etc.

### Work Reports

Reports are generated via API endpoints or triggered from the chat widget. The generator collects:

- **Time Entries**: Hours logged with project, issue, and activity details
- **Issues Assigned**: New tasks assigned during the report period
- **Issue Change History**: Full timeline of status/priority/assignee changes during the period
- **Issues Closed**: Tasks completed during the period
- **Status Summary**: Distribution of open issues by status
- **Overdue Issues**: Tasks past their due date but not yet closed
- **Comments**: Notes written on issues, wiki pages, documents
- **Wiki Updates**: Pages edited during the period

Reports are generated in Markdown format with structured sections, summarized via AI for readability.

## Architecture

```
redmine_ai_assistant/
├── init.rb                          # Plugin registration, permissions, settings
├── config/
│   ├── routes.rb                    # API routes
│   └── locales/                     # i18n (zh.yml, en.yml)
├── app/
│   ├── controllers/ai_assistant/
│   │   ├── chat_controller.rb       # Chat send/history/clear APIs
│   │   ├── reports_controller.rb    # Report generation APIs
│   │   └── providers_controller.rb  # Provider CRUD (admin)
│   ├── models/ai_assistant/
│   │   ├── ai_provider.rb           # AI service provider model
│   │   └── ai_message.rb            # Chat message persistence
│   └── views/ai_assistant/
│       ├── chat/_widget.html.erb    # Floating widget HTML
│       ├── chat/_head_tags.html.erb # CSS/JS resource injection
│       └── providers/               # Provider management views
├── assets/
│   └── {javascripts,stylesheets}/ai_assistant/
│       ├── chat_widget_controller.js  # ~770 lines, vanilla JS chat widget
│       └── chat_widget.css            # ~725 lines, styled chat UI
├── lib/ai_assistant/
│   ├── ai_client.rb                 # Unified OpenAI-compatible API client
│   ├── guard_prompt.rb              # Read-only guard prompt injection
│   ├── report_generator.rb          # Work report data collection & AI generation (~580 lines)
│   └── hooks.rb                     # Redmine view hooks
└── db/migrate/                      # Database schema migrations
```

### Key Components

**`ai_client.rb`** — Multi-provider HTTP client supporting all OpenAI-compatible APIs. Handles request building, timeout management, response parsing, error classification, and post-processing (including automatic issue ID linkification).

**`guard_prompt.rb`** — When business data keywords are detected in the conversation, injects a read-only constraint into the system prompt. Uses `Setting.app_title` for dynamic system name.

**`report_generator.rb`** — Core report engine:
- Computes report date range based on type (daily/weekly/monthly) and optional period offset
- Queries user's time entries, assigned issues, change history, closed issues, comments, wiki updates
- **Status Summary**: Groups open issues by status with counts and percentages
- **Overdue Detection**: Finds issues past `due_date` but not yet closed
- **Version Grouping**: Includes `fixed_version` name in issue data for version-level analysis
- Formats all data into structured Markdown for AI consumption
- All issue IDs are rendered as clickable Markdown links (`[#ID](url)`)

**`chat_widget_controller.js`** — Pure vanilla JavaScript chat widget:
- Draggable floating button with open/close toggle
- Markdown rendering with syntax highlighting, table support, and link handling
- Quick question templates for common queries
- Conversation history loading and new conversation controls
- Turbo/Turbolinks compatibility with proper event listener cleanup
- Debounce protection against duplicate initialization from multiple page load events

## API Reference

All API endpoints require authentication.

### Chat

| Method | Endpoint | Description |
|---|---|---|
| POST | `/ai_assistant/chat/send_message` | Send a message and get AI response |
| GET | `/ai_assistant/chat/history` | Get conversation history |
| GET | `/ai_assistant/chat/clear` | Clear a conversation |

**Send Message** request body:
```json
{
  "message": "What are my tasks today?",
  "conversation_id": "optional-conversation-uuid"
}
```

**Send Message** response:
```json
{
  "conversation_id": "uuid",
  "message": {
    "id": 42,
    "role": "assistant",
    "content": "Markdown formatted response...",
    "tokens_used": 1234
  }
}
```

### Reports

| Method | Endpoint | Description |
|---|---|---|
| GET | `/ai_assistant/reports/daily` | Generate today's daily report |
| GET | `/ai_assistant/reports/weekly` | Generate this week's weekly report |
| GET | `/ai_assistant/reports/monthly` | Generate this month's monthly report |
| POST | `/ai_assistant/reports/generate` | Generate a custom report |

**Generate Report** request body:
```json
{
  "report_type": "weekly",
  "period_offset": "-1",
  "provider_id": "optional-provider-id"
}
```

`period_offset`: `0` = current period, `-1` = previous period (yesterday/last week/last month).

## Database Schema

### `ai_providers`

| Column | Type | Description |
|---|---|---|
| `name` | string | Provider display name |
| `slug` | string | Unique identifier |
| `provider_type` | string | `tdp` or `custom` |
| `api_url` | string | API base URL |
| `api_key` | text | Encrypted API key |
| `default_model` | string | Default model name |
| `available_models` | text | JSON array of model names |
| `settings` | text | JSON extra configuration |
| `is_enabled` | boolean | Enabled status (default true) |
| `is_builtin` | boolean | Whether built-in (default false) |
| `position` | integer | Sort order (default 0) |

### `ai_messages`

| Column | Type | Description |
|---|---|---|
| `user_id` | integer | User reference |
| `ai_provider_id` | integer | AI provider reference |
| `conversation_id` | string | Conversation group ID |
| `role` | string | `user` or `assistant` |
| `content` | text | Message content |
| `model` | string | AI model used |
| `tokens_used` | integer | Token consumption |
| `report_type` | string | `daily`, `weekly`, or `monthly` (for reports) |
| `ai_provider` | string | Provider name snapshot |

## Development

### Adding a New AI Provider

1. Go to **Administration** → **AI Service Providers** → **New Provider**
2. Fill in the API URL and key for any OpenAI-compatible service
3. Set as default in Plugin Settings if desired

### Extending Report Data

The `ReportGenerator#collect_data` method returns a hash of all collected data. To add new data sources:

1. Add a new `fetch_*` method in `report_generator.rb`
2. Include the new key in `collect_data`
3. Add the corresponding section in `build_user_prompt`
4. Update `build_system_prompt` with guidelines for the new data

### Customizing the System Prompt

Use the **Custom System Prompt** setting in plugin configuration to inject custom rules. This prompt is prepended to every AI call (both chat and reports), allowing you to:
- Restrict AI to answer only within certain domains
- Define output format conventions
- Enforce company-specific policies

## License

This project is part of the Redmine ecosystem. See the main project license for details.
