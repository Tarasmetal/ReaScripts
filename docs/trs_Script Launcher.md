[⬅️ Main](../README.md)

[![English](https://img.shields.io/badge/en-English-blue.svg?style=for-the-badge)](trs_Script%20Launcher.md) [![Русский](https://img.shields.io/badge/ru-Русский-red.svg?style=for-the-badge)](trs_Script%20Launcher_ru.md)

# 🚀 trs_Script Launcher — Your Personal Script Control Center

> *Forget about endless searching in the Action List. Meet an elegant solution for launching and managing REAPER scripts.*

![Demo](../img/trs_Script_Launcher.gif)

---

## 📖 About the Script

**trs_Script Launcher** is a powerful file manager and script launcher for REAPER that transforms the chaos of hundreds of scripts into an organized system with an intuitive interface. No more need to register every script in the Action List — just launch them directly!

### ✨ Key Features

- 🗂️ **File Browser** — Navigate script folders with a tree structure
- ⭐ **Favorites System** — Quick access to frequently used scripts
- 📜 **Run History** — Track recently executed scripts
- 🔍 **Smart Search** — Instant search by filenames
- 🎯 **Drag & Drop** — Drag to reorder items in Favorites
- ⚡ **Quick Launch** — Double-click or Enter to execute
- 💾 **Auto-Save** — All settings are saved automatically
- 🎨 **Modern Interface** — Built on ReaImGui with theme support
- 🔄 **Context Menus** — Right-click for additional actions
- 📂 **Multi-format** — Supports `.lua`, `.eel`, `.py` scripts

---

## 🖥️ Interface Overview

The Script Launcher interface is divided into several functional zones:

### Top Toolbar
- **"Up" Button** — Go up one level in the folder structure
- **Path Field** — Displays the current directory
- **"Home" Button** — Quick return to the root script folder
- **Search Field** — Filter files by name

### Left Panel — Folder Tree
Tree structure of all available script directories. Clicking a folder instantly displays its contents in the central panel.

### Central Panel — File List
The main working area with a table of files:
- **"Name" Column** — Filename with type icon
- **"Size" Column** — File size
- **"Modified" Column** — Last modification date

### Right Panel — Tabs
- **📂 Files** — View files in the current folder
- **⭐ Favorites** — List of favorite scripts with drag & drop capability
- **📜 History** — Last launched scripts

### Bottom Status Bar
Displays the number of files in the current folder and overall statistics.

---

## 💡 Practical Use Cases

### Example 1: Workflow Organization

**Task:** You have 10 scripts that you use daily for mixing.

**Solution:**
1. Open Script Launcher
2. Find the desired script via search or browser
3. Right-click → "Add to Favorites"
4. Repeat for all 10 scripts
5. Go to the "⭐ Favorites" tab
6. Drag scripts into the desired order (most important at the top)

**Result:** Now all your working tools are in one place, in the correct order, always at hand!

---

### Example 2: Testing New Scripts

**Task:** You downloaded a package of 50 new scripts and want to test them without cluttering the Action List.

**Solution:**
1. Unpack scripts into any folder
2. In Script Launcher, press "Home" and navigate to this folder
3. Double-click a script to launch
4. The script will execute WITHOUT being added to the Action List
5. Check the "📜 History" tab — all launches are recorded

**Result:** Clean Action List + full testing history!

---

### Example 3: Quick Access to Project Scripts

**Task:** For a specific project, you created a set of specialized scripts.

**Solution:**
1. Create a "MyProject Scripts" folder in the REAPER directory
2. Place all project scripts there
3. In Script Launcher, navigate to this folder
4. Add the folder to bookmarks (if the feature is available)
5. Use search to instantly find the needed script

**Result:** All project tools are isolated and accessible in two clicks!

---

### Example 4: Working with History

**Task:** You ran a script yesterday but forgot its name.

**Solution:**
1. Open Script Launcher
2. Go to the "📜 History" tab
3. Browse the list of recent launches
4. Find the desired script by date/time
5. Double-click to run again
6. Or add to favorites for future use

**Result:** Launch history — your insurance against forgetfulness!

---

## 🔥 Advanced Features

### Hotkeys
- **Enter** — Launch selected script
- **Delete** — Remove from favorites (on Favorites tab)
- **Ctrl+F** — Focus on search field
- **Escape** — Clear search

### Context Menu (Right-Click)
- **Run Script** — Launch script
- **Add to Favorites** — Add to favorites
- **Remove from Favorites** — Remove from favorites
- **Show in Explorer** — Open file location
- **Copy Path** — Copy full file path

### Drag & Drop in Favorites
Drag scripts in the Favorites list to change their order. The new order is saved automatically!

### Smart Filtering
Search works in real-time and matches any part of the filename. Case-insensitive.

### Automatic Saving
All changes (favorites, history, window size, position) are saved to `trs_Script Launcher.ini` automatically upon closing.

---

## ⚙️ Technical Details

### System Requirements
- **REAPER** version 6.0 or higher
- **ReaImGui** extension (installed via ReaPack)
- **Operating System:** Windows, macOS, Linux

### Supported Script Formats
- `.lua` — Lua scripts
- `.eel` — EEL2 scripts
- `.py` — Python scripts

### Configuration File
Settings are stored in `GUI Tools/trs_Script Launcher.ini`:
```ini
[Window]
width=1200
height=700

[Favorites]
script1=path/to/favorite/script.lua
script2=path/to/another/script.eel

[History]
last1=path/to/recent/script.lua
last2=path/to/previous/script.py
```

### Execution Details
Scripts are launched via `reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS..."), 0)` WITHOUT registration in the Action List. This means:
- ✅ Clean Action List
- ✅ No ID conflicts
- ✅ Can run temporary/test scripts
- ✅ No REAPER restart required

### Performance
- Directory scanning occurs asynchronously
- Folder structure caching for fast navigation
- Optimized rendering of large file lists

---

## 🎯 Get Started Now!

1. **Install** the script via ReaPack or manually
2. **Launch** from the Action List: `Script: trs_Script Launcher`
3. **Configure** favorites for your workflow
4. **Enjoy** organized script work!

### Tips for Starting:
- Add Script Launcher itself to REAPER favorites for quick access
- Create separate folders for different task types (Mixing, Editing, MIDI, etc.)
- Use clear filenames — it simplifies searching
- Regularly check history — maybe a script should be added to favorites

---

## 📞 Support and Feedback

- **Author:** Taras Umanskiy
- **Version:** 2.0
- **Link:** [VK](http://vk.com/tarasmetal)
- **Support the Project:** [Donation](https://vk.com/Tarasmetal)

---

<div align="center">

**Developed with ❤️ for the REAPER community**

</div>
