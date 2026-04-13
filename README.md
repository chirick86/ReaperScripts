# Chirick's Subtitle Scripts

Scripts for REAPER to work with subtitles and voiceover for video content — import, export, visualization, and real-time display.

[![REAPER](https://img.shields.io/badge/REAPER-6.0+-blue?style=flat-square)](https://forum.cockos.com/showthread.php?p=2935723)
[![Reddit](https://img.shields.io/badge/Reddit-Discussion-orange?style=flat-square)](https://www.reddit.com/r/Reaper/comments/1skaa8e/chiricks_subtitle_scripts_subtitle_voiceover/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Patreon](https://img.shields.io/badge/Support-Patreon-orange?style=flat-square)](https://patreon.com/chirick)
[![Ko-fi](https://img.shields.io/badge/Support-Ko--fi-red?style=flat-square)](https://ko-fi.com/chirick)
[![YouTube](https://img.shields.io/badge/YouTube-Channel-red?style=flat-square)](https://youtu.be/sM-Q4fyQ2ds)

## 📺 Video Presentation

<a href="https://youtu.be/sM-Q4fyQ2ds">
  <img src="https://i.ytimg.com/vi/sM-Q4fyQ2ds/hqdefault.jpg" alt="Chirick Subtitle Scripts — Presentation" width="100%" style="max-width:600px" />
</a>

## ⚡ Installation

1. Install [ReaPack](https://reapack.com/)
2. In REAPER: **Extensions → ReaPack → Import repositories...**
3. Paste the URL and click OK:

   ```
   https://github.com/chirick86/ReaperScripts/raw/master/index.xml
   ```

4. **Extensions → ReaPack → Browse packages** → search "Chirick"

## 🎯 Typical Usage Scenario

1. **Import** subtitles from SRT/ASS file as text items or regions
2. **Prompter** — read the script during voiceover recording
3. **SubOverlay** — display subtitle text over the video in real-time
4. **Export** the finished layout back to SRT

## 📦 Scripts

### 🎬 Subtitle Scripts

No additional dependencies required.

| Script | Description |
|--------|-------------|
| **Import text items from subtitles** | Imports SRT/ASS as text items. Each item's timing and text match the subtitle. For ASS with roles — separate track per role |
| **Import regions from subtitles** | Imports SRT/ASS as project regions. For ASS with roles — unique color per role |
| **Export items to SRT** | Exports all items from the selected track to SRT. Text is taken from item Notes |
| **Export regions to SRT** | Exports all project regions to SRT. Region names become subtitle text |
| **Create text items from regions** | Converts project regions into text items on a new track. Region names → item Notes |
| **Create regions from text items** | Converts text items on the selected track into project regions. Item Notes → region names |
| **Convert SWS subtitles to regions** | Converts SWS S&M subtitle markers into full project regions. ⚠️ Save the project before running |
| **Delete markers** | Deletes all markers in the current project |
| **Delete regions** | Deletes all regions in the current project |
| **Icons and fonts** | Installs toolbar icons and fonts for the subtitle scripts |

### 🖥️ ReaImGui Scripts

Real-time GUI tools. Require [ReaImGui](https://github.com/cfillion/reaimgui) (install via ReaPack).

| Script | Description |
|--------|-------------|
| **Prompter** | Script/teleprompter panel — shows regions or text items as a scrollable list, highlights the current line during playback, supports click-to-jump navigation, search, and combined regions+items view. Can auto-launch SubOverlay on start. **Requires:** ReaImGui + JS_ReaScript Extensions |
| **SubOverlay** | Subtitle overlay on the REAPER video window — shows current and next line during playback. Attaches to and follows the video window. Supports transparent background, progress bar, font/color/shadow customization, and "fill gaps" mode. **Requires:** ReaImGui |

## ✨ Key Features

✅ **SRT and ASS formats** — with auto-encoding detection (UTF-8, CP1251, CP866)  
✅ **ASS role separation** — separate tracks or unique colors per character  
✅ **Batch import** — multiple files at once with format auto-detection  
✅ **Bidirectional conversion** — regions ↔ text items  
✅ **Real-time display** — Prompter and SubOverlay sync with playback position  
✅ **Fully customizable UI** — fonts, colors, sizes, transparency for each element  
✅ **Video window integration** — SubOverlay follows the REAPER video window  

## 📋 Requirements

| Component | Required for |
|-----------|-------------|
| REAPER 6.0+ | All scripts |
| ReaPack | Installation and updates |
| ReaImGui | Prompter, SubOverlay |
| JS_ReaScript Extensions | Prompter |

## 🎨 Icons & Fonts

The `icons_fonts_readme` folder contains toolbar icons and font recommendations. After installation via ReaPack — copy icons to `REAPER\Data\toolbar_icons` and assign them via right-click on the toolbar button.
