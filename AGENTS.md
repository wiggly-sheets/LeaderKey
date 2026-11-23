# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

# Leader Key Development Guide

This is the independent Wiggly Sheets fork of Leader Key. Do not describe it as affiliated with,
endorsed by, or supported by the upstream project or its author.

## Build & Test Commands

Do not build or run the app unless the user asks.

- Build and run: `xcodebuild -scheme "Leader Key" -configuration Debug build`
- Run all tests: `xcodebuild -scheme "Leader Key" -testPlan "TestPlan" test`
- Run single test: `xcodebuild -scheme "Leader Key" -testPlan "TestPlan" -only-testing:Leader KeyTests/UserConfigTests/testInitializesWithDefaults test`
- Release builds are one bundle per architecture, built by `.github/workflows/release.yml` on a
  `v*` tag: `ARCHS=arm64` and `ARCHS=x86_64` with `ONLY_ACTIVE_ARCH=NO`, ad-hoc signed, then packed
  into separate disk images
- Bump version: `bin/bump`
- Create release: `bin/release`

## Architecture Overview

Leader Key is a macOS application that provides customizable keyboard shortcuts. The core architecture consists of:

**Key Components:**

- `AppDelegate`: Application lifecycle, global shortcuts registration, update management
- `Controller`: Central event handling, manages key sequences and window display
- `UserConfig`: JSON configuration management with validation
- `UserState`: Tracks navigation through key sequences
- `MainWindow`: Base class for theme windows
- `URLSchemeHandler`: URL commands, including exact-label named actions
- `TextInserter`: Accessibility-gated synthetic text insertion for text actions
- `CheatsheetSearch` / `FuzzyMatcher`: Cheatsheet search and fuzzy ranking

**Theme System:**

- Themes inherit from `MainWindow` and implement `draw()` method
- Available themes: MysteryBox, Mini, Breadcrumbs, ForTheHorde, Cheater
- Each theme provides different visual representations of shortcuts

**Configuration Flow:**

- Config stored at `~/Library/Application Support/Leader Key/config.json`
- `FileMonitor` watches for changes and triggers reload
- `ConfigValidator` ensures no key conflicts
- Actions support: applications, URLs, commands, folders, text snippets
- Command actions support `{{clipboard}}`; use `\{{clipboard}}` for a literal placeholder
- Named deep links run only a unique, exact action label and require URL scheme automation
- The fork disables Sparkle updates and the original release feed

**Testing Architecture:**

- Uses XCTest with custom `TestAlertManager` for UI testing
- Tests use isolated UserDefaults and temporary directories
- Focus on configuration validation and state management

## Code Style Guidelines

- **Imports**: Group Foundation/AppKit imports first, then third-party libraries (Combine, Defaults)
- **Naming**: Use descriptive camelCase for variables/functions, PascalCase for types
- **Types**: Use explicit type annotations for public properties and parameters
- **Error Handling**: Use appropriate error handling with do/catch blocks and alerts
- **Extensions**: Create extensions for additional functionality on existing types
- **State Management**: Use @Published and ObservableObject for reactive UI updates
- **Testing**: Create separate test cases with descriptive names, use XCTAssert\* methods
- **Access Control**: Use appropriate access modifiers (private, fileprivate, internal)
- **Documentation**: Use comments for complex logic or non-obvious implementations

Follow Swift idioms and default formatting (4-space indentation, spaces around operators).

