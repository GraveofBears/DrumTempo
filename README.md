
DrumTempo is a streamlined World of Warcraft addon designed to optimize the use of Leatherworking Drums. It provides a reactive, single-button interface that tracks usage, identifies drummers, and manages the Tinnitus lockout period with high precision.

## Features

* **Smart Lockout Tracking:** Automatically detects the Tinnitus debuff and starts a 120-second formatted (M:SS) countdown timer.
* **Drummer Identification:** Displays the name of the last person to use drums directly on the frame until the debuff period ends.
* **Dynamic Visuals:** * Greys out (desaturates) the drum icon while you are under the effect of Tinnitus.
    * Features a 30-second sweeping cooldown overlay to track the active buff duration.
* **Reliable Icon Caching:** Includes advanced logic to prevent the "Question Mark" icon bug common during initial login.
* **Customization:** Full integration with **LibSharedMedia** and **Ace3** to allow for custom fonts, text sizing, and icon scaling.
* **Automation:** Optional party/raid chat announcements when you use your drums.

## Installation

1. Download the repository.
2. Extract the folder into your `World of Warcraft/_classic_/Interface/AddOns/` directory.
3. Ensure the folder is named `DrumTempo`.

## Slash Commands

* `/pdrums` - Opens the configuration menu.

## File Structure

* `DrumTempo.lua`: Core logic and event handling.
* `DrumData.lua`: Item and Spell database for all TBC-era drums.
* `Frames.lua`: UI construction and visual state management.
* `Options.lua`: Configuration panel and database settings.
* `Layouts/SimpleDrum.lua`: The primary display layout.

## Technical Details

DrumTempo uses a **SecureActionButtonTemplate**, ensuring that your drum button remains functional and clickable even when the addon updates the icon or text during combat.

---
# DrumTempo
**Author:** Gravebear  
TBC Classic WoW Addon
