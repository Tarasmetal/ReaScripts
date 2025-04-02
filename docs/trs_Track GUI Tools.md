[⬅️ Main](../README.md)

[![English](https://img.shields.io/badge/en-English-blue.svg?style=for-the-badge)](trs_Track%20GUI%20Tools.md) [![Русский](https://img.shields.io/badge/ru-Русский-red.svg?style=for-the-badge)](trs_Track%20GUI%20Tools_ru.md)

# 🛠️ RENAME TRACKS GUI TOOLS

**RENAME TRACKS GUI TOOLS** is a powerful and intuitive tool designed for quick project organization. The script provides a graphical interface for instant track renaming, pan and color management, and automation of routine tasks such as numbering and creating L/R pairs.

---
![Demo](../img/trs_TrackGUITools.gif)
---

## 🚀 Key Features

- 📝 **Instant Renaming**: Change the names of selected tracks with one click.
- 🎨 **Color Management**: Automatic track coloring according to the selected preset.
- 🎚️ **Panning**: Ability to set pan values for specific track types.
- 📂 **Preset System**: Create, save, and switch between different toolsets.
- 🔢 **Auto-Indexing**: Quick numbering of duplicate track names (e.g., Vox 1, Vox 2).
- ↔️ **L/R Routing**: Automatic addition of L and R suffixes for stereo pairs.
- 🖱️ **Drag & Drop**: Drag buttons in the interface to change their order.
- ⚙️ **Context Menu**: Edit button parameters directly in the interface via right-click.

---

## 🖥️ Interface Overview

### 1. Control Panel (Top Section) 🛠️
- **PRESETS**: Opens a popup menu with a list of available preset files (.txt).
  - **New**: Create a new empty preset.
  - **Clear**: Remove all buttons from the current preset.
  - **Delete**: Remove the current preset file.
- **SAVE AS**: Allows saving the current set of buttons to a new file.
- **`<` and `>` Buttons**: Quickly switch between available preset files in the `TrackPresets` folder.
- **Preset Name**: Displays the name of the active set (highlighted in yellow).
- **Index**: Scans all selected tracks and, if it finds identical names, adds a sequence number to them.
- **LR**: Searches for pairs of tracks with the same name and adds "L" to the first and "R" to the second (supports space, underscore, or hyphen separators).
- **Clone**: 
  - **Left Click**: Adds selected track names to the preset list.
  - **Right Click**: Clones track names and attempts to split them into prefix and suffixes.

### 2. Button Grid 🎹
Each button in the grid corresponds to a specific track name. The button color (shaded) reflects the color that will be assigned to the track when pressed.
- **Left Click**: Renames all selected tracks, applies color and pan (if configured).
- **Click and Drag**: Allows moving a button to another position in the list.
- **START Button**: A large, flashing button that appears in the center for empty presets, allowing you to quickly add the first row.

---

## 🖱️ Advanced Settings (Right-Click) ⚙️

Right-clicking any button opens the edit context menu:

- **Edit Name**: Change the text on the button and the track name.
- **Enable Pan**: Toggle pan management for this button.
- **Pan Value**: Set the pan value (from -100 to 100).
- **Enable Color**: Toggle track color change.
- **Color Picker**: Choose a color via the standard palette or enter a HEX code.
- **Add Suffix**: Add a new suffix cell to the current row.
- **Add Row**: Insert a new row after the current one.
- **Delete Row**: Remove the entire row.

---

## ⌨️ Hotkeys and Mouse Controls

For maximum efficiency, the following commands are implemented in the script:

### Keyboard ⌨️
- **`W`**: Select the previous track (up).
- **`S`**: Select the next track (down).
- **`Insert`**:
  - Hover over main button — Add a new row.
  - Hover over suffix button — Add a new suffix to the row.
- **`Delete`**:
  - Hover over main button — Delete the entire row.
  - Hover over suffix button — Clear the suffix text.
- **`Enter` / `Num Enter`**: Confirm input in text fields and close edit windows.
- **`Escape`**: Quickly close the script window.

### Mouse 🖱️
- **Left Click (LMB)**:
  - On the main button — Full rename + color + pan.
  - On the suffix button — Adds text to the current track name.
- **Middle Click (MMB)**:
  - On the suffix button — **Replaces** the track name with the suffix text (instead of adding).
- **Right Click (RMB)**:
  - On any button — Opens the settings menu (editing name, color, pan).
  - In the color menu — RMB click on the color icon copies the color from the currently selected track in REAPER.
- **Drag & Drop**:
  - Drag main buttons to change their order.
  - Drag suffix buttons to move or swap them.

---

## 📁 Preset System and Files 🗄️

The script stores settings in the `TrackPresets` folder, located in the script directory.

- **File Format**: `.txt`
- **Data Structure**: Name, Extra fields, Pan, Color (HEX).
- **Automation**: Upon the first launch, `default.txt` and `user.txt` files are created.

---

## 🔧 Requirements and Installation 📦

1. **REAPER**: Current version.
2. **ReaImGui**: Must be installed via ReaPack.
3. **SWS Extension**: Recommended for stable operation of some API functions.

---

## 💡 Usage Tips 💡

- To quickly rename a group of tracks, select them in the mixer or arrangement window and press the corresponding button in the script.
- Use the **Index** button after duplicating a track (e.g., guitars) to quickly get "Guitar 1" and "Guitar 2".
- The **LR** button is perfect for double-tracks: select two tracks named "Lead Gtr" and press LR — you will get "Lead Gtr L" and "Lead Gtr R".

---

<p align="center">
Developed with ❤️ for the REAPER community
</p>
