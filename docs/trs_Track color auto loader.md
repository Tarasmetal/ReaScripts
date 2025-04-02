[⬅️ Main](../README.md)

[![English](https://img.shields.io/badge/en-English-blue.svg?style=for-the-badge)](trs_Track%20color%20auto%20loader.md) [![Русский](https://img.shields.io/badge/ru-Русский-red.svg?style=for-the-badge)](trs_Track%20color%20auto%20loader_ru.md)

# 🤖 Track Color Auto Loader & Gradients v1.8

![Author](https://img.shields.io/badge/Author-Taras%20Umanskiy-blue)
![Version](https://img.shields.io/badge/Version-1.8-green)
![Platform](https://img.shields.io/badge/Platform-Windows%20%2F%20macOS-orange)
![API](https://img.shields.io/badge/API-Reaper%20%2F%20ReaImGui-red)

## **📖 Description**
**Track Color Auto Loader & Gradients** is a powerful intelligent tool for automating the visual organization of your project in REAPER. The script allows you to instantly color tracks based on their names using a flexible system of rules, as well as create professional gradients for folder contents.

This eliminates routine manual coloring, making navigation in complex projects fast and intuitive.

---

## **✨ Key Features**
- **Name-based Automation:** Color tracks by prefixes, suffixes, or text matches in the name.
- **Advanced Gradients:** Create smooth color transitions for tracks within folders (support for 2-point and 3-point gradients).
- **"Receive" Rule Type:** A unique ability to color a track based on which track is sending a signal to it (ideal for processing buses).
- **Preset System:** Save different color schemes for different tasks (recording, mixing, sound design) and quickly switch between them.
- **Context Integration:** Copy the color of a selected track directly into the rule's palette via right-click.
- **Headless Mode:** Ability to run the script without opening the window (apply colors and exit immediately).
- **Undo-safe:** Full support for REAPER's undo history.

---

## **🛠️ How It Works**
1. **Name Analysis:** The script scans all tracks in the project and looks for name matches according to your list of rules.
2. **Priorities:** Prefix and suffix rules take priority over general folder rules, allowing for flexible configuration of exceptions within gradients.
3. **Gradient Calculation:** If a track is a folder and a `Folder` rule is set for it, the script automatically distributes colors among all child tracks, creating a uniform transition from start to end (and optionally middle) color.
4. **Links (Receives):** When using the `Receive` type, the script checks the sources of sends to the track and looks for name matches among them.

---

## **🚀 Usage**

### **Step 1: Create Rules**
1. Click **"Add Rule"** to create a new rule.
2. Select type:
    - `Prefix`: search for a match at the beginning of the name.
    - `Suffix`: search for a match at the end of the name.
    - `Folder`: create a gradient for folder contents.
    - `Receive`: color based on the send source name.
3. Enter the text (Pattern) that the script should look for in the track name.

### **Step 2: Choose Colors**
- Click on the color square to select it manually.
- **Pro Tip:** Right-click the color square to instantly copy the color of the active (selected) track from your project.

### **Step 3: Apply**
Click **"Run / Apply Colors"**. The script will instantly color all matching tracks in the project. If modification is enabled, rules will be automatically saved to the current preset.

### **Step 4: Manage Presets**
Use the **"File"** menu to save (`Save`), create copies (`Save As`), or load existing rule sets.

---

## **Changelog**
### **v1.8**
- ✅ Added support for 3-point gradients (Start-Mid-End) for folders.
- ✅ New `Receive` rule type for coloring buses by signal source.
- ✅ `RUN_WITHOUT_GUI` mode for automatic application on startup.
- ✅ Copy track color via RMB on the palette.
- ✅ Performance optimization for large projects.

---

## **Contact and Support**
- **Author:** Taras Umanskiy
- **VK:** [vk.com/tarasmetal](http://vk.com/tarasmetal)
- **Support the Project:** [vk.com/Tarasmetal](https://vk.com/Tarasmetal)

<p align="center">Developed with ❤️ for the REAPER community</p>
