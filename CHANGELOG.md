# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- RAG-like functionality for intelligent note context
  - Vector store for semantic note indexing
  - Automatic note indexing on save
  - Configurable similarity threshold and context size
  - Support for OpenAI and Gemini embeddings
- Multi-provider chat support with OpenAI, Google Gemini, Anthropic Claude, and DeepSeek
- Configurable model selection for each provider
- Improved error handling and response parsing for chat functionality
- Environment variable support for API keys
- Documentation for chat configuration and usage

## [v0.1.1] - 2025-02-10

### Added
- Enhanced debugging system across all components
- Comprehensive debug logging for preview functionality
- Browser-based preview with Bracey.vim support
- Import & Sort functionality in menu
- Custom bookmarking system with categories
- YAML link handling with frontmatter preservation
- New debug logging for popup menu and icons

### Fixed
- Menu system syntax and formatting
- Markdown preview functionality and reliability
- YAML parsing and frontmatter preservation
- Search functionality and dependency handling
- Bookmark view count errors
- Statistics view count error
- Icons dictionary formatting
- Popup menu structure and commands

### Changed
- Improved statusline implementation and format
- Enhanced menu icons and sync options
- Simplified session management
- Standardized debug tags across components
- Rewritten YAML frontmatter handling for better efficiency
- Renamed commands for better clarity (iso_save/load to VisidianSave/Load)

### Documentation
- Added comprehensive debugging documentation
- Updated README with recommended usage
- Added Buy Me a Coffee button
- Clarified dependencies and YAML parser options
- Added ASCII header and reorganized command list

## [v0.1.0] - Initial Release

### Added
- Initial implementation of Visidian
- Basic note-taking functionality
- PARA folder structure support
- Session management
- Basic preview functionality
- Initial search implementation

[v0.1.1]: https://github.com/ubuntupunk/visidian.vim/compare/v0.1.0...v0.1.1
[v0.1.0]: https://github.com/ubuntupunk/visidian.vim/releases/tag/v0.1.0
