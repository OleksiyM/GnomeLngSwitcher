# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-10-15

### Added
- Declared GNOME Shell 5.1 / 51 compatibility in extension metadata (`extension/metadata.json`) for Ubuntu 26.10.
- Updated documentation and website requirements to include GNOME Shell 45 – 51 and Ubuntu 26.10.

## [1.0.1] - 2026-10-06

### Fixed
- Reaped terminated child GUI processes to prevent zombie processes.
- Updated dark theme screenshot on documentation site.

## [1.0.0] - 2026-10-06

### Added
- First stable release of GnomeLngSwitcher.
- Signed release packaging with Sigstore provenance and SHA-256 checksums.
- Native GTK 4 and Libadwaita settings application with live daemon status.
- GNOME Shell companion extension for Wayland and X11 layout switching over D-Bus.
