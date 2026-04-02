[⬅️ Main](../README.md)

[![English](https://img.shields.io/badge/en-English-blue.svg?style=for-the-badge)](trs_Track%20vol%20pan%20fx%20auto%20Save%20Restore.md) [![Русский](https://img.shields.io/badge/ru-Русский-red.svg?style=for-the-badge)](trs_Track%20vol%20pan%20fx%20auto%20Save%20Restore_ru.md)

# trs_Track vol pan fx auto Save Restore

> **A powerful tool for managing mix snapshots in REAPER.**  
> Save and restore volume, pan, and effects settings with a single click.

---

![Demo](../img/trs_Track_vol_pan_fx_auto_Save_Restore.png)

---

| Information | Value |
| :--- | :--- |
| **Author** | Taras Umanskiy |
| **Technology** | Lua, ReaImGui |
| **License** | MIT / Proprietary (see repository) |
| **Links** | [GitHub](https://github.com/Tarasmetal/ReaScripts) \| [Donation](https://vk.com/Tarasmetal) |

---

## 📖 Description

This script is designed for mixing engineers and producers working in REAPER. It allows you to **save the current state of your mix** (volume, pan, FX status) to a file and **restore it** at any time.

This is especially useful for:
- **A/B Comparison**: Quickly switch between your current mix and a "reset" state.
- **Stem Preparation**: Temporarily disable processing and level the tracks.
- **Experiments**: Save a "return point" before making major changes.

Data is saved to a `TrackMixSnap.txt` file created directly in the project folder, ensuring portability along with the project.

## ✨ Key Features

### 🎛️ Parameter Management
The script allows you to flexibly choose which parameters to save and restore:

*   **Volume:** Saves exact fader values. When clicking *Save*, all tracks are set to a user-defined level (default is -3 dB).
*   **Pan:** Saves pan positions. When clicking *Save*, pan is reset to Center.
*   **FX:** Remembers the state of each plugin on the track (Enabled/Bypass, Offline/Online). When clicking *Save*, effects can be bulk bypassed to hear the "raw" signal.
*   **Automation:** Manage Global Automation Override mode.

### 🖥️ Modern GUI
The interface is built using the **ReaImGui** library, providing:
- Smooth performance and responsiveness.
- Integration with OS/REAPER themes.
- Compact window size ("Always Auto Resize").
- Persistence of interface settings between sessions.

## ⚙️ Requirements

The following extensions are required for the script to work:

1.  **REAPER** (version 6.x or 7.x).
2.  **ReaImGui**: UI rendering library (installed via ReaPack).
3.  **SWS Extension**: (Optional, but recommended) used for advanced FX control commands (e.g., `_SWS_DISMASTERFX`).

> **Note:** If ReaImGui is not installed, the script will display a warning and will not run.

## 🚀 How to Use

1.  Launch the script from the Action List.
2.  In the window that appears, configure the **checkboxes** for the parameters you want to process:
    -   `[x] Volume` (set the reset level next to it, e.g., `-3.0`)
    -   `[x] Pan`
    -   `[x] FX`
    -   `[x] Automation`
3.  **Saving (Resetting):**
    -   Click the **Save** button.
    -   The script will write current track settings to a file.
    -   It will then apply the "reset" (set volume to the specified value, pan to center, bypass FX), allowing you to hear the raw material.
4.  **Restoring:**
    -   Click the **Restore** button.
    -   The script will read data from the file and return all settings (faders, knobs, plugins) to their original state.

## 📂 File Structure

The script creates helper files in your project's root directory (`.rpp`):

*   `TrackMixSnap.txt`: Stores track parameter snapshot (Volume, Pan, FX states).
*   `TrackMixFlags.txt`: Stores the script's own settings (checkbox states and target volume value).

---

## Changelog
* **1.2.1**
    * Fixed links and filenames.
