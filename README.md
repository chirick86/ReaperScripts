# Chirick Subtitle Scripts

A comprehensive collection of scripts for working with subtitles in REAPER.

![REAPER](https://img.shields.io/badge/REAPER-6.0+-blue?style=flat-square)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Patreon](https://img.shields.io/badge/Support-Patreon-orange?style=flat-square)](https://patreon.com/chirick)
[![Ko-fi](https://img.shields.io/badge/Support-Ko--fi-red?style=flat-square)](https://ko-fi.com/chirick)

## 📦 Packages

This repository contains two package categories:

### 🎬 Subtitle Scripts
Core subtitle tools for import, export, and conversion operations. No additional dependencies required.

- **Import text items from subtitles** - Import SRT/ASS subtitles as text items
- **Import regions from subtitles** - Import SRT/ASS subtitles as project regions  
- **Export items to SRT** - Export text items from selected track to SRT file
- **Export regions to SRT** - Export project regions to SRT file
- **Create text items from regions** - Convert project regions to text items on new track
- **Create regions from text items** - Convert text items on selected track to project regions
- **Convert SWS subtitles to regions** - Convert SWS S&M subtitles to full timeline regions

### 🖥️ Subtitle ReaImGui Scripts *(Advanced GUI tools)*
Real-time subtitle tools with graphical interface.

- **Prompter** - Prompter with automatic synchronization
- **SubOverlay** - Subtitle overlay over REAPER video window

> ⚠️ Requires [ReaImGui](https://github.com/cfillion/reaimgui) (install via ReaPack)

## ⚡ Quick Start

### Installation via ReaPack (Recommended)

1. Install [ReaPack](https://reapack.com/) if you haven't already
2. In REAPER: **Extensions** → **ReaPack** → **Import repositories...**
3. Paste this URL and click OK:
   ```
   https://github.com/chirick86/ReaperScripts/raw/master/index.xml
   ```
4. Go to **Extensions** → **ReaPack** → **Browse packages**
5. Search for "Chirick" and install the packages you need

### Manual Installation

1. Download last realese from the [Releases]
2. Copy the `chirick` folder to your REAPER Scripts folder:
   - **Windows:** `%APPDATA%\REAPER\Scripts\`
   - **macOS:** `~/Library/Application Support/REAPER/Scripts/`
   - **Linux:** `~/.config/REAPER/Scripts/`
3. In REAPER: **Actions** → **Show action list** → **New action** → **Load ReaScript...**
4. Navigate to the `Subtitles` folder and select the scripts you want to use

## 🎯 Typical Usage Scenario

1. **Import:** Use "Import text items from subtitles" to import an SRT/ASS file
2. **Display:** Open "Prompter" for comfortable reading during recording
3. **Overlay:** Run "SubOverlay" to display text over video in real-time

## ✨ Key Features

### Import & Export
✅ **Multiple encodings support** – UTF-8, CP1251, CP866  
✅ **ASS format support** – Automatic role separation with unique colors  
✅ **Batch processing** – Multiple file import with format auto-detection  
✅ **Instant import** – No waiting while items are being placed  
✅ **Flexible handling** – Empty lines allowed, lines can start with numbers  
✅ **First region preserved** – First region line doesn't disappear  

### Display & Visualization
✅ **Special characters** – Accents and special symbols display correctly  
✅ **Flexible display modes** – Switch between regions, items, or combined view  
✅ **Smart filtering** – Muted tracks automatically excluded from Prompter  
✅ **Project memory** – Prompter remembers selected display mode for each project  

### Advanced GUI Features (ReaImGui)
✅ **Full customization** – Fonts, colors, sizes for each element  
✅ **Video window attachment** – SubOverlay follows REAPER video window  
✅ **Responsive overlay** – Automatically hides when REAPER is inactive or minimized  
✅ **Multi-track support** – Flexible track switching and display options  

## 📋 Requirements

- **REAPER** 6.0 or later
- **ReaPack** (for installation and auto-updates)
- **ReaImGui** (for Prompter and SubOverlay – install via ReaPack)
- **JS_ReaScript Extensions** (for Prompter – install via ReaPack)

## Scripts Structure

### Export Scripts
- **Export items to SRT** - Export text items from selected track to SRT file
  - Text is taken from item Notes
  - Standard SRT format with timecodes
  
- **Export regions to SRT** - Export project regions to SRT file
  - Region names become subtitle text
  - Quick way to create subtitles from project marking

### Conversion Scripts
- **Create text items from regions** - Convert project regions to text items
  - Creates new track automatically
  - Region names transferred to item Notes
  - Timing matches perfectly
  
- **Create regions from text items** - Convert text items to project regions
  - Select a track with items
  - Item Notes transferred to region names
  - Useful for timeline marking

- **Convert SWS subtitles to regions** - Convert SWS S&M subtitles to full timeline regions
  - Reads currently open (saved) project .rpp file
  - Extracts subtitle data and creates full regions
  - **Note:** Backup project before running!

### Subtitle ReaImGui Scripts

Advanced GUI tools for working with subtitles. **Requires ReaImGui** (install via ReaPack).

#### Install ReaImGui

1. **Extensions** → **ReaPack** → **Browse packages**
2. Search for "ReaImGui"
3. Right-click on **ReaImGui: ReaScript binding for Dear ImGui**
4. Click **Install** → **Apply**

#### Scripts

- **Prompter** - Prompter for subtitles
  - Shows regions or text items as scrollable list
  - Automatically highlights current line during playback
  - Click on line to jump to position (+ copies text to clipboard)
  - Customizable fonts, colors, and sizes for regions and items separately
  - Search with highlighted results
  - "All elements" mode - combines regions and items in timeline order
  - Smooth scrolling and current line magnification
  - Muted track items are excluded from display
  - Remembers selected display mode for each project
  - **Requires:** ReaImGui + JS_ReaScript Extensions

- **SubOverlay** - Subtitle overlay over video
  - Shows current and next region/item text during playback
  - Can be attached to REAPER video window (automatically follows it)
  - Customizable fonts, colors, shadows for each line
  - Progress bar shows current region/item progress
  - Smart line wrapping, vertical and horizontal alignment
  - Transparent background, hide title bar for minimalist display
  - "Fill gaps" mode - shows nearest text even between regions
  - Only visible when REAPER is active or maximized
  - **Requires:** ReaImGui

## Resources

The `icons_fonts_readme` folder contains additional resources:
- Toolbar icons for scripts
- Font recommendations
- Detailed documentation (Readme.txt)

To use toolbar icons:
1. Copy icons to `REAPER\Data\toolbar_icons` folder
2. Add scripts to toolbar
3. Right-click on toolbar button → Set button icon

