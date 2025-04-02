[⬅️ Main](../README.md)

[![English](https://img.shields.io/badge/en-English-blue.svg?style=for-the-badge)](trs_Track%20automation%20mode%20toggle.md) [![Русский](https://img.shields.io/badge/ru-Русский-red.svg?style=for-the-badge)](trs_Track%20automation%20mode%20toggle_ru.md)

# 🤖 Toggle track automation mode v1.3

![Author](https://img.shields.io/badge/Author-Taras%20Umanskiy-blue)
![Version](https://img.shields.io/badge/Version-1.3-green)
![Platform](https://img.shields.io/badge/Platform-Windows%20%2F%20macOS-orange)
![API](https://img.shields.io/badge/API-Reaper%20%2F%20ReaImGui-red)

## **📖 Description**
**Toggle track automation mode** is a modern graphical interface for managing automation modes in REAPER. The script provides quick and visual access to all standard automation modes, allowing you to instantly switch them for all selected tracks simultaneously.

By using **ReaImGui**, the interface looks professional, works smoothly, and supports color indication consistent with REAPER standards.

---

## **✨ Key Features**
- **Full Control:** Support for all modes: `Trim/Read`, `Read`, `Touch`, `Write`, `Latch`, `Latch Preview`.
- **Color Indication:** Buttons of active modes are highlighted with corresponding colors (green for Read, red for Write, etc.).
- **Intelligent Status:** The script shows the current mode of selected tracks. If tracks have different modes, it displays the `Mixed` status.
- **Smart Toggle:** A special button for quick switching between `Touch` and `Trim/Read` — an ideal solution for live automation.
- **Group Management:** Changes are applied to all selected tracks in one click.
- **Undo/Redo:** All actions are correctly recorded in REAPER's undo history.

---

## **🛠️ How It Works**
1. The script monitors selected tracks in the project in real-time.
2. When a mode button is pressed, the script iterates through all selected tracks and applies the corresponding `SetTrackAutomationMode` command.
3. The interface updates dynamically, highlighting the button of the currently active mode.
4. The **Toggle** function analyzes the current state: if the `Touch` mode is selected, it switches to `Trim/Read`; in any other case, it enables `Touch`.

---

## **🚀 Usage**

### **Step 1: Select Tracks**
Select one or more tracks whose automation modes you want to change.

### **Step 2: Choose Mode**
Simply click the button with the desired mode in the script window. The current active mode will be highlighted in color, and the status text at the top of the window will confirm the changes.

### **Step 3: Quick Switch (Toggle)**
Use the large **"TOGGLE: TOUCH <-> TRIM"** button at the bottom of the window for rapid workflow. This is especially useful when recording parameter automation "on the fly," allowing you to quickly enter record mode and return to reading.

---

## **Changelog**
### **v1.3**
- ✅ Fixed compatibility with newer versions of ReaImGui (replaced deprecated functions).
- ✅ Code optimization and improved stability.
- ✅ Enhanced button color scheme.

---

## **Contact and Support**
- **Author:** Taras Umanskiy
- **VK:** [vk.com/tarasmetal](http://vk.com/tarasmetal)
- **Support the Project:** [vk.com/Tarasmetal](https://vk.com/Tarasmetal)

<p align="center">Developed with ❤️ for the REAPER community</p>
