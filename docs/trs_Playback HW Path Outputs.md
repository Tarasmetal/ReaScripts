[⬅️ Main](../README.md) | [Русский](trs_Playback%20HW%20Path%20Outputs_ru.md)

# trs_PlayBack Routing

## Description
**trs_PlayBack Routing** is a Lua script for REAPER featuring a graphical user interface based on **ReaImGui**. The script is designed to automatically route tracks in a project based on their names. It is an ideal tool for quickly setting up playback or preparing a multitrack for output to the physical outputs of an audio interface.

The script allows you to create a configuration where specific track names correspond to specific hardware outputs. When applying the settings, the script automatically disables the master send and assigns direct hardware outputs.

## Main Features

*   **Automatic Routing:** Searches for tracks in the project by name and assigns them to the corresponding hardware outputs.
*   **Output Type Management:** Supports both **Stereo** and **Mono** outputs.
*   **Master Isolation:** Automatically disables the "Master Send" for routed tracks.
*   **Master Track Control:** Option to globally mute/unmute all hardware outputs of the master track.
*   **Preset System:**
    *   Save and load configurations to text files.
    *   Automatically restores the last used preset when the script is launched.
*   **Easy Editing:** Add and remove tracks from the configuration list directly in the interface.

## Requirements

*   **REAPER** (latest version recommended)
*   **ReaImGui** (GUI library, installed via ReaPack)
*   **SWS Extension** (recommended for proper track management functions)

## Usage Instructions

### Interface
The script window is divided into a preset management panel and a routing list.

#### 1. Track List Setup
In the settings table, you can define parameters for each track type:
*   **Track Name:** Enter the exact track name as it appears in the REAPER project (e.g., `PB`, `CLICK`, `BASS`).
*   **Output:** Specify the first channel number of the hardware output.
    *   *To the right of the name, the resulting channel range is displayed (e.g., `1-2` or `3`).*
*   **Type:** Select the mode:
    *   **stereo:** A pair of outputs is used (e.g., 1-2).
    *   **mono:** A single mono channel is used.

**Row Management:**
*   **Add Row:** Press the **`Insert`** key on your keyboard.
*   **Delete Row:** Click on the track name input field to focus it, then press the **`Delete`** key.

#### 2. "Master Track" Option
The **Master Track** checkbox controls the state of the hardware outputs of the REAPER project's master track itself:
*   **[ x ] Enabled:** All hardware outputs of the master track will be **unmuted**.
*   **[   ] Disabled:** All hardware outputs of the master track will be **muted**.

#### 3. Applying Settings
Click the **"Apply Routing"** button. The script will perform the following actions:
1.  Scan all tracks in the project.
2.  If a track's name matches one of the settings:
    *   Disable the "Master Send" checkbox.
    *   Remove all current Hardware Sends on that track.
    *   Create a new Hardware Send according to the settings (channel number and mono/stereo mode).
3.  Apply the Mute/Unmute settings to the Master track's outputs.

### Working with Presets
*   **Load Preset:** Opens a standard dialog to select a saved settings file.
*   **Save Preset:** Allows you to save the current configuration under a new name. Files are saved in the `RoutingPresets` folder next to the script.

## Author
**Taras Umanskiy**
*   **VK:** [http://vk.com/tarasmetal](http://vk.com/tarasmetal)
*   **Donation:** [https://vk.com/Tarasmetal](https://vk.com/Tarasmetal)
*   **GitHub:** [https://github.com/Tarasmetal/ReaScripts](https://github.com/Tarasmetal/ReaScripts)

---
Developed with ❤️ for the REAPER community.