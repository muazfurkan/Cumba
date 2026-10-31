# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Menu bar app skeleton: no Dock icon, a status item with Settings, Pause and Quit.
- Settings window with a General tab and launch at login.
- English and Turkish localization, with a test that fails on missing Turkish strings.
- XcodeGen project, `os.Logger` setup and a single source for the app version.
- CI workflow (build, test, swift-format lint) and a release workflow that publishes an ad-hoc signed zip.
- Contributor docs: README in Turkish, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, issue and pull request templates.
