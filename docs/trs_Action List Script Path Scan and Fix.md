[⬅️ Main](../README.md)

[🇬🇧 English](trs_Action%20List%20Script%20Path%20Scan%20and%20Fix.md) | [🇷🇺 Русский](trs_Action%20List%20Script%20Path%20Scan%20and%20Fix_ru.md)

# 🤖 Action List Script Path Scan and Fix

**Action List Script Path Scan and Fix** is a powerful tool for REAPER users that helps maintain a clean Action List by identifying and fixing broken script links.

---

## 📋 Description
The script scans the `reaper-kb.ini` configuration file and checks for the existence of script files at the specified paths. If a file is not found (e.g., after deleting a repository or manually moving files), the script marks it as "broken" and offers solutions.

## ✨ Key Features
- **Deep Scanning**: Checks all registered ReaScripts in the Action List.
- **Smart Search**: Recognizes both absolute and relative paths (including the `Scripts` folder).
- **Safe Fixing**: Automatically removes broken entries from `reaper-kb.ini`.
- **Backup**: Creates a backup of `reaper-kb.ini` before making any changes.
- **Repository Analysis**: Attempts to determine which ReaPack repository the missing script came from.
- **Action List Integration**: Quick search and copying of script IDs via the context menu.
- **Data Export**: Ability to save a list of missing repository URLs to a text file.

## 🛠 Installation and Requirements

The following components are required for the script to work correctly:
1. **REAPER** (version 6.0 or higher).
2. **ReaImGui**: Available via ReaPack (extension for creating graphical user interfaces).
3. **JS_ReaScriptAPI** (optional): Required for automatically inserting text into the Action List filter.

### How to install:
1. Copy the `trs_Broken Script Path Scan and Fix.lua` file to your REAPER scripts folder.
2. Add it to the Action List (`Actions` -> `Show action list...` -> `New action` -> `Load ReaScript...`).

## 🚀 Usage Instructions

### 1. Scanning
- Run the script.
- Click the **"Scan Action List"** button.
- The script will display a table with all broken scripts found.

### 2. Analyzing Results
The table displays:
- **Command ID**: The unique identifier of the command.
- **Script Name**: The name under which it appears in the Action List.
- **File Path**: The path where REAPER is trying to find the file.

### 3. Fixing Errors
- Click the **"Fix Errors"** button.
- Confirm the action. The script will remove the entries from `reaper-kb.ini` and create a backup in the same folder.
- **Important**: After removing entries, it is recommended to restart REAPER or refresh the Action List.

### 4. Working with Repositories
- If you want to know which repositories need to be reinstalled, click **"Show Repository"**.
- You can copy the repository URL or save the entire list to a `Broken_Repos_List.txt` file.

## 🛡 Security
The script is designed with a priority on keeping your data safe:
- **No files are deleted from your drive**. The script only works with entries in the configuration file.
- Before every fix, a backup file like `reaper-kb.ini.backup_YYYYMMDD_HHMMSS` is created.

---

## 🔗 Links
- **Author**: Taras Umanskiy
- **Version**: 1.7.3
- **Support/Contact**: [VK.com/tarasmetal](http://vk.com/tarasmetal)
- **Donation**: [Support the author](https://vk.com/Tarasmetal)

---