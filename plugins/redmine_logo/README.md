# Redmine Logo Plugin

Customizable logo plugin for Redmine 6.1.x with text/image support, multi-node deployment, system URL override, and 29-language support.

![screenshots](screenshots/2.png)

## Features

- **Text & Image Logos**: Custom text (max 30 chars) or image uploads (JPG/PNG/GIF/SVG)
- **Base64 Storage**: Images stored in database for multi-node compatibility
- **Type Switching**: Seamlessly switch between text/image without losing settings
- **System URL Override**: Replace default `http://localhost:3000` globally
- **29 Languages**: Complete UI localization including RTL support
- **AJAX Upload**: Real-time upload with preview
- **Custom Head Content**: Insert `<style>`/`<script>` tags
- **Responsive Design**: Mobile-optimized

## Requirements

- Redmine 6.1.0+
- Ruby 2.7+
- Rails 6.1+

## Installation

```bash
cd /path/to/redmine/plugins
git clone https://github.com/carolcoral/redmine_logo.git redmine_logo
cd /path/to/redmine
bundle install
touch tmp/restart.txt  # Restart Redmine
```

## Configuration

**Access**: Login as Admin → **Administration → Logo Management**

1. **Enable/Disable**: Toggle logo display
2. **System URL** (Optional): Replace default `http://localhost:3000`
3. **Logo Type**: Choose **Text** or **Image**
   - **Text**: Enter text (≤30 chars), colors, font weight
   - **Image**: Upload image (converted to base64)
4. **Display**: Set position, margin, padding
5. **Custom Head** (Optional): Insert `<style>`/`<script>` tags
6. **Save**: Click **Save**

### Multi-Node Deployment

Fully compatible with multi-node setups:

- **Base64 Storage**: Images in database, no file system needed
- **Settings Atomicity**: All config in `Setting.plugin_redmine_logo`
- **Easy Backup**: Database backup includes everything

### System URL Override

Replace `http://localhost:3000` globally (emails, plugins, URLs):

- Enter full URL: `https://redmine.example.com`
- Verify: `bundle exec rails runner "puts home_url"`
- See [CUSTOM_SYSTEM_URL_README.md](CUSTOM_SYSTEM_URL_README.md) for details

## Usage Examples

- **Text**: "MyCompany" (orange first letter, bold, left)
- **Image**: Upload → Preview → Save (max 120px width)
- **Custom Head**: Add analytics or custom CSS/JS

## Technical Details

- **Storage**: Database-only (base64 for images)
- **Hooks**: `view_layouts_base_html_head`, `view_layouts_base_body_bottom`
- **CSS Prefix**: `redmine_logo-`
- **Compatibility**: Chrome 20+, Firefox 29+, Safari 12.1+, Edge 18+

## Troubleshooting

**Logo not displaying**
- Check enable status, clear cache (Ctrl+Shift+R), verify settings
- Restart Redmine, check browser console

**Image upload fails**
- Check JavaScript console, verify permissions
- Review Redmine logs, check format (JPG/PNG/GIF/SVG)
- Ensure settings preserved, note: base64 storage (no files)

**URL override not working**
1. Confirm saved settings
2. Restart Redmine
3. Clear cache: `RAILS_ENV=production bundle exec rake tmp:cache:clear`
4. Verify in console: `bundle exec rails runner "puts home_url"`

**Settings not preserved when switching**
- Enable JavaScript, clear cache, check console
- Verify database connection (base64 storage)

## License

MIT License

## Support

- GitHub: https://github.com/carolcoral/redmine_logo
- Issues: https://github.com/carolcoral/redmine_logo/issues

## Changelog

### Version 1.0.3 (2026-02-13)
- **Base64 Image Storage**: Images stored in database for multi-node support
- **Settings Preservation**: Switch text/image types without losing data
- **Bug Fixes**: Fixed display issues, preview clearing, type switching
- **Multi-language**: Updated all 29 language files

### Version 1.0.2 (2026-02-04)
- Fixed button jitter, optimized insertion, live type switching

### Version 1.0.1 (2026-02-03)
- Custom head content, CSS isolation, mobile optimizations

### Version 1.0.0 (2026-02-02)
- Initial release
