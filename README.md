**DrumTempo** is a streamlined World of Warcraft addon designed to optimize the use of Leatherworking Drums. It provides a reactive, single-button interface that tracks usage, identifies drummers, and manages the Tinnitus lockout period with high precision.

---

## 🛠 Features

* **Smart Lockout Tracking:** Automatically detects the Tinnitus debuff and starts a formatted countdown timer.
* **Drummer Identification:** (Default Layout) Displays the name of the player who last used drums directly on the frame.
* **Dynamic Visuals:** * Greys out (desaturates) the drum icon while you are under the effect of Tinnitus.
    * Features a 30-second sweeping cooldown overlay to track the active buff duration.
* **Reliable Icon Caching:** Advanced logic ensures your drum icons load correctly on login, preventing the common "Question Mark" bug.
* **Customization:** Full integration with **LibSharedMedia** and **Ace3** for real-time adjustments to fonts, text sizing, and icon scaling.
* **Automation:** Optional party/raid chat announcements when you use your drums.

---

## 🎨 Layout Options

DrumTempo now features two distinct visual modes to fit your UI preference:

### 1. Default Drum Layout
The full-information experience. Designed for players who want maximum data at a glance.
* **Top Text:** Displays the name of the person who just drummed.
* **Center Text:** Shows the precise M:SS countdown of your Tinnitus lockout.
* **Charge Tracker:** Displays remaining drum stacks in the bottom right.

### 2. Minimal Drum Layout
The "Clean UI" experience. Perfect for minimalists who only want to see what is strictly necessary.
* **Pure Icon:** Hides names and timers for a distraction-free look.
* **Smart Indicators:** Still displays your **Charge Count** and uses a **Golden Shine** (via LibCustomGlow) to alert you the moment the icon returns to color and is ready for use.
* **Desaturation:** Automatically greys out during lockout to signify it is unusable.

---

## 🚀 Installation

1. Download the repository.
2. Extract the folder into your `World of Warcraft/_classic_/Interface/AddOns/` directory.
3. Ensure the folder is named `DrumTempo`.

---

## ⌨️ Slash Commands

* `/drumtempo` or `/dt` - Opens the configuration menu.

---

## ⚙️ Technical Details

DrumTempo is built on a **SecureActionButtonTemplate**. This is critical for high-end raiding as it ensures your drum button remains functional and clickable even when the addon updates icons, text, or desaturation levels during intense combat.

# DrumTempo
**Author:** Gravebear  
**Category:** TBC Classic WoW Addon
