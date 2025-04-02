[⬅️ Main](../README.md)

[![English](https://img.shields.io/badge/en-English-blue.svg?style=for-the-badge)](trs_VST%20Macro%20Linker.md) [![Русский](https://img.shields.io/badge/ru-Русский-red.svg?style=for-the-badge)](trs_VST%20Macro%20Linker_ru.md)

![Demo](../img/trs_VST_Macro_Linker_demo.png)

# 🎛️ VST Macro Linker — User Documentation

**VST Macro Linker** is a powerful tool for REAPER DAW designed to control VST plugin parameters via macros and pads. The script allows you to create complex links, manage them using external MIDI controllers, and automate the linking process.

---

## 🚀 Key Features
- **16 Macros**: Smooth parameter control (Knobs/Sliders).
- **16 Pads**: Control triggers and switches (Buttons).
- **Auto-Linking**: Fast "on-the-fly" parameter assignment mode.
- **Intelligent Automation**: Full integration with a JSFX backend for recording automation.
- **Flexible Range Control**: Individual Min/Max settings, inversion, and Offset for each link.
- **MIDI Learn**: Simple binding of your hardware to the script's interface.
- **Smart Parameters Window**: The settings window is now always at hand, snapping to the main interface.

---

## 🛠️ Installation and Setup
1. Launch the script `trs_VST Macro Linker.lua`.
2. Upon first launch (or when enabling the **Automation** checkbox), the script will prompt you to install the JSFX backend.
3. A special track named `VST Macro Linker` with the corresponding plugin will be created in your project. **Do not delete it** if you plan to record macro automation.

---

## 🔗 Parameter Linking Modes

### 🖱️ Manual Mode
1. Touch any parameter in a VST plugin.
2. Click the **Link** button next to the desired macro in the script window.

### ⚡ Auto-Link
1. Press the **L** hotkey. The `● AUTO-LINK ACTIVE` indicator will appear.
2. Simply turn parameters in plugins — they will be automatically assigned to free macros.
3. **Target Selection**: Press numbers **1-9** on your keyboard in this mode to lock linking to a specific macro.
4. **Middle Mouse Button**: Clicking the **Link** or **Pad** button sets it as the next target for auto-linking.

---

## ⌨️ Hotkeys
| Key | Action |
| :--- | :--- |
| **L** | Toggle Auto-Link mode |
| **H** | Show/hide the Linked Parameters window |
| **1 - 9** | Select target macro in Auto-Link mode |
| **Ctrl + R-Click** | Toggle MIDI Learn for the selected Pad |

---

## 🖱️ Mouse Actions
- **Left Click (Link)**: Bind the last touched parameter to the macro.
- **Middle Click (Link/Pad)**: Set as target for auto-linking.
- **Right Click (Link)**: Remove all bound parameters from this macro.
- **'M' Button (Learn)**: Enable MIDI Learn for the macro (waiting for MIDI CC or Note).

---

## ⚙️ Linked Parameters Window
This window allows you to fine-tune the behavior of each bound parameter:
- **Min / Max**: Set the range of parameter movement.
- **Invert**: Invert the direction (e.g., macro up — parameter down).
- **Offset**: Shift the modulation range (macros only).
- **X**: Remove a specific link.
- **L / S**: Load and save link configurations to an `.ini` file.

> 💡 **Tip**: The window automatically snaps to the right side of the main window for better workspace organization.

---

## 🤖 Automation
The script supports standard REAPER automation modes for macros:
- **Read**: Read recorded automation.
- **Touch / Latch**: Record macro movements.
- **Write**: Complete overwrite of automation.

Mode selection buttons are located at the top of the interface.

---

## 📂 Data Saving
- **MIDI Presets**: Saved in the `MacroPresets` folder within the script directory.
- **Project Data**: All parameter links are saved automatically next to the project file in `ProjectName_ML.ini` format.

---

<p align="center">
Developed with ❤️ for the REAPER community
</p>
