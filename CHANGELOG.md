# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### 📚 Documentation
- **README**: Full pub.dev-ready README with badges, features table, quick start guide
- **doc/ folder**: Comprehensive documentation (installation, configuration, authentication, profile, teams, notifications, views, CLI, architecture)
- **CLAUDE.md**: Rewrite to match Magic ecosystem format

### 🔧 Improvements
- **Publishing**: Prepare package metadata, CI/CD workflows, and issue templates for pub.dev

## [0.0.1-alpha.1] - 2026-03-25

### ✨ Core Features
- **Authentication**: Login, register, forgot/reset password with email and phone identity modes
- **Guest Auth**: OTP-based phone login with send and verify flow
- **Two-Factor Authentication**: Enable/disable 2FA with QR code setup, OTP confirmation, and recovery codes
- **Social Login**: OAuth integration with configurable providers
- **Profile Management**: Photo upload, email/password change, email verification, session management, timezone selection
- **Extended Profile**: Additional profile fields with locale and timezone defaults
- **Teams**: Create teams, switch active team, invite members, manage roles
- **Notifications**: Real-time polling, mark read/unread, notification preference matrix
- **Newsletter**: Simple subscribe/unsubscribe controller
- **13 Feature Toggles**: All opt-in — teams, profile_photos, registration, two_factor, sessions, guest_auth, phone_otp, newsletter, email_verification, extended_profile, social_login, notifications, timezones
- **9 Gate Abilities**: Authorization checks for profile sections (photo, email, phone, password, verify-email, two-factor, newsletter, sessions, delete-account)
- **View Registry**: String-keyed view factory — host app can override any screen or layout
- **Wind UI**: Tailwind-like className system — no Material widgets in layouts
- **CLI Tools**: install, configure, doctor, publish, uninstall commands with stub templates
- **2 Layouts**: AppLayout (authenticated) and GuestLayout (auth pages)
- **12 Views**: 6 auth, 1 profile, 3 teams, 2 notifications
- **10 Widgets**: Reusable Wind UI components (auth form card, card, password confirm dialog, team selector, notification dropdown, two-factor modal, timezone select, user profile dropdown, social divider, page header)
