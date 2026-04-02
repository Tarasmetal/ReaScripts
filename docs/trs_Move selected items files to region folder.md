[⬅️ Main](../README.md) [![English](https://img.shields.io/badge/en-English-blue.svg?style=for-the-badge)](trs_Move%20selected%20items%20files%20to%20region%20folder.md) [![Русский](https://img.shields.io/badge/ru-Русский-red.svg?style=for-the-badge)](trs_Move%20selected%20items%20files%20to%20region%20folder_ru.md)

# 🤖 Move selected items files to region folder v1.2

![Author](https://img.shields.io/badge/Author-Taras%20Umanskiy-blue)
![Version](https://img.shields.io/badge/Version-1.2-green)
![Platform](https://img.shields.io/badge/Platform-Windows%20%2F%20macOS-orange)
![API](https://img.shields.io/badge/API-Reaper%20%2F%20ReaImGui-red)

## **📖 Description**
**Move selected items files to region folder** is a specialized tool for organizing your project's media files. The script automatically moves the source files of selected items into subfolders named after the regions where these items are located.

This is an ideal solution for structuring data when recording takes, working with sound libraries, or preparing assets for games, where files need to be categorized into folders.

---

## **✨ Key Features**
- **Automatic Sorting:** Files are physically moved into subfolders within your project directory.
- **Two Detection Modes:** 
    - By item position (each item goes to its own region's folder).
    - By cursor position (all items go to the folder of the region under the cursor).
- **Safe Preview:** A table displays original names and future paths before executing the move.
- **Smart Name Cleanup:** Automatically replaces invalid characters in region names with safe underscores.
- **SWS and Shell Support:** Multiple layers of verification for reliable file moving on Windows and macOS.
- **Automatic Path Updating:** REAPER instantly recognizes the new file locations without losing the connection (Media Offline -> Online).

---

## **🛠️ How It Works**
1. The script analyzes selected items and locates their source files on the disk.
2. It checks for the presence of regions at the specified position (cursor or item start).
3. It generates a new path: `Project_Path / Region_Name / File_Name`.
4. Temporarily sets the items to **Offline** state to unlock file access.
5. Physically moves the files and updates the project references to the new locations.
6. Returns the items to **Online** state.

---

## **🚀 Usage**

### **Step 1: Select Items**
Select one or more items in the arrange view whose files you want to move.

### **Step 2: Configure Mode**
Choose the appropriate mode in the script window:
- **"Use Edit Cursor Position" checked:** The script will find the region where your edit cursor is located and suggest moving all selected files specifically to that region's folder.
- **Unchecked (default):** The script will individually determine the region where each item starts.

### **Step 3: Scanning**
Click the **"Scan Selected Items"** button. The table will populate with a list of files ready to be moved and their future paths.

### **Step 4: Moving**
If everything looks correct, click the **"MOVE FILES"** button. The script will perform the operation and update the status.

---

## **Changelog**
### **v1.2**
- ✅ Added option to use item position for region determination.
- ✅ Improved directory creation logic.
- ✅ Optimized the Offline/Online switching process.

---

## **Contact & Support**
- **Author:** Taras Umanskiy
- **VK:** [vk.com/tarasmetal](http://vk.com/tarasmetal)
- **Support the project:** [vk.com/Tarasmetal](https://vk.com/Tarasmetal)

<p align="center">Developed with ❤️ for the REAPER community</p>