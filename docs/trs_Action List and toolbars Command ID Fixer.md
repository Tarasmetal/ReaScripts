[🇬🇧 English](trs_Action%20List%20and%20toolbars%20Command%20ID%20Fixer.md) | [🇷🇺 Русский](trs_Action%20List%20and%20toolbars%20Command%20ID%20Fixer_ru.md)

[⬅️ Main](../README.md)

# 🤖 Action List and toolbars Command ID name Fixer v1.6

![Author](https://img.shields.io/badge/Author-Taras%20Umanskiy-blue)
![Version](https://img.shields.io/badge/Version-1.6-green)
![Platform](https://img.shields.io/badge/Platform-Windows%20(x64)-orange)
![API](https://img.shields.io/badge/API-Reaper%20%2F%20ReaImGui-red)

![Command ID name Fixer](../img/trs_Action%20List%20and%20toolbars%20Command%20ID%20name%20Fixer.png)

## **Overview**
**Action List and toolbars Command ID name Fixer** is a powerful tool for REAPER users that helps to tidy up action configuration files (`reaper-kb.ini`) and menus (`reaper-menu.ini`). The script replaces automatically generated IDs (e.g., `RS7d3c_...`) with meaningful names based on the script description.

This makes your configuration files readable and makes it easier to migrate settings between different REAPER installations.

---

## **Key Features**
- **Safe Mode:** Pre-analysis and a preview table allow you to choose exactly which IDs to replace.
- **Smart Name Cleanup:** Automatically removes `Script:`, `Custom:` prefixes, file extensions, and invalid characters.
- **Hotkeys Support:** Updates not only script registrations (`SCR`), but also key bindings (`KEY`).
- **Menu Processing:** Synchronizes changes with the `reaper-menu.ini` file.
- **Backup:** Automatically creates `.bck` files before making any changes.
- **Filtering:** Ability to search for specific scripts for targeted processing.

---

## **Requirements**
- **REAPER** (latest version recommended).
- **ReaImGui** (available via ReaPack).
- **Windows** OS (x64 for optimal font rendering).

---

## **Usage Instructions**

### **Step 1: File Selection**
Run the script and click the **"Select file (reaper-kb.ini)"** button. Usually, this file is located in the REAPER resource folder (Options -> Show REAPER resource path...).

### **Step 2: Analysis**
1. (Optional) Enter text in the **"Filter"** field to find specific scripts.
2. Click **"Analyze"**. The script will scan the file and show a table with possible replacements.

### **Step 3: Review and Apply**
1. In the preview table, you will see:
   - **Description:** Original name of the script.
   - **Old ID:** Current technical ID.
   - **New ID:** Generated readable ID.
2. Check the boxes for the items you want (or use "Select All").
3. Click **"APPLY CHANGES"**. The script will update `reaper-kb.ini` and create a backup.

### **Step 4: Update Menu**
After successfully updating `reaper-kb.ini`, click **"Process Menu"**. The script will find `reaper-menu.ini` in the same folder and update the ID links in your custom menus.

---

## **Technical Details**

### **Naming Logic**
The script converts names according to the following rules:
1. Conversion to lowercase.
2. Replacing spaces with underscores (`_`).
3. Removing special characters: `. , ( ) [ ] + ' : "'`.
4. Removing extensions: `.lua`, `.eel`, `.py`.
5. Adding suffixes for specific sections:
   - MIDI Editor: `_me`
   - MIDI Event List: `_mie`

### **Safety**
The script works in memory and writes changes only after your confirmation. Creating backups ensures that you can roll back to the previous state in case of an error.

---

## **Changelog**
### **v1.6**
- ✅ Implemented "Safe Mode" with preview of changes.
- ✅ Separation of analysis and application logic.
- ✅ Preview table with checkboxes.
- ✅ "Process Menu" button for synchronization.
- ✅ Backup creation (`*.ini.bck`).
- ✅ Search filter added.

---

## **Contacts & Support**
- **Author:** Taras Umanskiy
- **VK:** [vk.com/tarasmetal](http://vk.com/tarasmetal)
- **Support the project:** [vk.com/Tarasmetal](https://vk.com/Tarasmetal)

<p align="center">Developed with ❤️ for the REAPER community</p>