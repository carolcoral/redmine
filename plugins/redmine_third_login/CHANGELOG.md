# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-03-02

### Added
- Initial release of Redmine Third Login Plugin
- Support for multiple login types (Local, LDAP, DingTalk)
- Dynamic login form switching based on selected login type
- DingTalk QR code login integration
- User matching by mobile phone number
- Plugin configuration page
- Comprehensive error handling and logging
- Multi-language support (English and Chinese)
- Responsive UI design matching Redmine native style
- Detailed documentation and installation guide

### Features
- **Login Type Selector**: Dropdown menu on login page to choose login method
- **Dynamic Form Adaptation**: Show/hide fields based on selected login type
- **DingTalk Integration**: Full OAuth2 flow with DingTalk Open Platform
- **QR Code Generation**: Dynamic QR code generation for DingTalk login
- **User Matching**: Automatic user matching via mobile phone custom field
- **Error Handling**: Graceful error messages and comprehensive logging
- **Security**: CSRF protection, state validation, secure token handling

### Technical Details
- Compatible with Redmine 6.1.1+
- Ruby 3.0+ and Rails 6.1+ support
- HTTParty for API calls
- Native JavaScript implementation (no external dependencies)
- Redmine plugin hooks for seamless integration
- MIT License

### Documentation
- Comprehensive README.md
- Detailed installation guide (INSTALL.md)
- Configuration examples (configuration.yml.example)
- English and Chinese translations
- Inline code comments

---

## [Unreleased]

### Planned Features
- Support for more third-party login providers (WeChat, GitHub, etc.)
- Auto-create users on first login
- Role mapping from third-party systems
- Advanced user provisioning
- Login analytics and reporting
- Remember login type preference
- Customizable UI themes
- API endpoints for mobile app integration

### Improvements
- Enhanced security features (2FA support)
- Performance optimizations
- Better error recovery mechanisms
- More detailed audit logging
- User self-service account linking

---

## Contributing

Please see [README.md](README.md) for details on contributing to this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Author**: carolcoral  
**GitHub**: [https://github.com/carolcoral](https://github.com/carolcoral)  
**Project**: [https://github.com/carolcoral/redmine_third_login](https://github.com/carolcoral/redmine_third_login)
