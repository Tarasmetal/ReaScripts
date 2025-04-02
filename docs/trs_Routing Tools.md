[⬅️ Main](../README.md) | [Русский](trs_Routing%20Tools_ru.md)

# trs_Routing Tools (SendBox) | MODDED by Taras Umanskiy

## Description
The **SendBox** script is designed to automate the creation and management of routing (sends/receives) for tracks in Reaper DAW. It provides a convenient Graphical User Interface (GUI) based on ReaImGui to quickly create sends between selected tracks in REAPER and tracks selected within the script's tree, with flexible channel and routing mode settings.

## Main Features
*   **Routing Modes**:
    *   **Send**: Creates sends from the tracks selected in REAPER to the tracks selected in the script interface.
    *   **Receive**: Creates receives on the tracks selected in REAPER from the tracks selected in the script interface.
*   **Send Position (Tap Point)**:
    *   Post-Fader
    *   Pre-Fader
    *   Pre-FX
*   **Channel Management**:
    *   Source Channels selection.
    *   Destination Channel selection.
    *   Support for routing up to 64 channels.
    *   Automatic increase of the number of track channels if required for the selected routing.
*   **Track Selection Interface**:
    *   Displays the project track tree, taking folder nesting into account.
    *   Track search by name.
    *   Displays track colors.
    *   Buttons to quickly collapse/expand the track tree.
*   **Quick Action**: Double-clicking a track in the list instantly creates the routing and closes the script.
*   **Settings Persistence**: The script remembers the last selected mode and send position.

## Requirements
The following extensions are required for the script to work:
1.  **SWS Extensions**: [https://www.sws-extension.org](https://www.sws-extension.org)
2.  **ReaImGui**: Available for installation via ReaPack.

## Usage

### 1. Preparation
Select one or more tracks in the main REAPER window that you want to work with (create sends *from* them or receives *to* them).

### 2. Parameter Setup
In the top menu bar of the script, select:
*   **Mode**: Send or Receive.
*   **FX** (Tap Point): Post-Fader, Pre-Fader, or Pre-FX.
*   **Channels**: Click the `Channels` button to open the channel configuration window. Select the Source channels and the Destination channel.

### 3. Target Track Selection
In the script's track list, check the boxes for the tracks that will be the other side of the routing.
*   Use the **Search** field to filter the list.
*   The arrow buttons allow you to collapse or expand all folders.
*   The **Clear** button (red) resets the track selection in the script's list.

### 4. Creating Routing
*   Click the green **RUN** button (in the menu or in the channels window) to create sends/receives.
*   **Alternative**: Double-clicking the left mouse button on a track in the script's list will automatically create the routing for that track and close the script.

## Configuration
The mode and tap point settings are saved to the `SendBoxConfig.txt` file in the REAPER resource folder and restored on the next launch.

## Information
*   **Author**: Taras Umanskiy
*   **Version**: 1.1.1
*   **Links**:
    *   [VK](http://vk.com/tarasmetal)
    *   [Donation (PayPal)](https://paypal.me/Tarasmetal)
    *   [Donation (VK)](https://vk.com/Tarasmetal)

---

## Changelog
* **1.1.1**
    * Fixed links and file names.