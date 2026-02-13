# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### Added

#### Subtitle Scripts Package
- **Import text items from subtitles** - Import SRT/ASS subtitles as text items
  - Multi-file selection support
  - Auto-encoding detection (UTF-8, CP1251, CP866)
  - ASS role separation into tracks
  
- **Import regions from subtitles** - Import SRT/ASS subtitles as project regions
  - Multi-encoding support
  - Unique color assignment for ASS roles
  
- **Export items to SRT** - Export text items to SRT format
  
- **Export regions to SRT** - Export project regions to SRT format
  
- **Create text items from regions** - Convert regions to text items
  
- **Create regions from text items** - Convert text items to regions
  
- **Convert SWS subtitles to regions** - Convert SWS S&M subtitles to full regions

#### Subtitle ReaImGui Scripts Package
- **Chirick Prompter** - prompter with real-time synchronization
  - Region and text item display
  - Auto-highlighting of current line
  - Search functionality
  - Customizable fonts and colors
  - Smooth scrolling
  - "All elements" mode
  
- **Chirick SubOverlay** - Subtitle overlay over video
  - Current and next text display
  - Video window attachment
  - Progress bar
  - Customizable appearance
  - "Fill gaps" mode

### Infrastructure
- ReaPack index.xml with two package categories
- Comprehensive README.md
- MIT License
- .gitignore for REAPER projects
- Full ReaPack metadata in all scripts

[1.0.0]: https://github.com/chirick/reaper-subtitle-scripts/releases/tag/v1.0.0
