[⬅️ Main](../README.md)

[🇬🇧 English](trs_Label%20GUI%20Tools.md) | [🇷🇺 Русский](trs_Label%20GUI%20Tools_ru.md)

# GUI Tools: trs_Label GUI Tools

## Description

**trs_Label GUI Tools** is a script for REAPER that provides a convenient graphical interface (based on the ReaImGui library) for managing and editing labels (item/take names) in your project.

The tool allows you to quickly rename groups of selected items using information about the track, region, and project tempo (BPM), as well as perform other useful operations with file names.

## Main Features

### Information Panel
* Displays the number of **selected items** (color indication depends on the count).
* Displays the current project **BPM** (Master Tempo).

### Renaming Tools (Presets)
The script contains a set of buttons for quickly renaming selected items according to specified templates:

* **EMPTY**: Clear the name.
* **RENAME Region Track**: Template `/r /T` (Region Name + Track Name).
* **RENAME Region Track BPM**: Template `/r /T [BPM]` (Region Name + Track Name + Tempo).
* **RENAME Name Only**: Template `/T` (Track Name only).
* **RENAME Name Index**: Template `/T_/E` (Track Name + Index).
* **RENAME Name Tuned**: Adds the "Tunned" mark.
* **RENAME Name Click**: Adds the "Click" mark.
* **RENAME Name_ [BPM]**: Track Name + Tempo.
* **RENAME Name Index [BPM]**: Track Name + Index + Tempo.

### Manual Control
* A text field for entering custom renaming templates (e.g., `/T /E`).
* **GO!** button to apply the entered template.

### Additional Features
* Integration with the SWS command: **Rename takes and source files** (allows renaming source files).

## Usage

1. Select one or more media items in the REAPER arrange view.
2. Run the `trs_Label GUI Tools.lua` script.
3. In the window that appears, select the desired preset by clicking the corresponding button.
4. Item names will be instantly updated according to the selected template.
5. For custom renaming, enter the template in the text field at the bottom and click **GO!**.

## Pattern Symbols

The script supports the following substitution symbols for forming names:

### Basic
* `/T` — Track Name.
* `/t` — Track Number.
* `/r` — Name of the region where the item is located (Region Name).
* `$notes` — Current item notes text (Item Notes).
* `\n` — Line break symbol.

### Counters
* `/E` — Global numbering across all selected items (1, 2, 3...).
* `/e` — Local item numbering within each track.
* `/I` — Reverse global numbering (from last to first).
* `/i` — Reverse local numbering (within the track).

### Advanced Counter Settings
For counters (`/E`, `/e`, `/I`, `/i`), an extended format is supported to specify the number of digits (leading zeros) and an offset:

**Syntax:** `/SymbolDigits_Offset_`

* `Digits` — number of digits (leading zeros).
* `Offset` — the number added to the counter.

**Examples:**
* `/E` — normal numbering: 1, 2, 3...
* `/E02_0_` — two digits: 01, 02, 03...
* `/E03_10_` — three digits, starting from 11 (1 + 10): 011, 012, 013...

---