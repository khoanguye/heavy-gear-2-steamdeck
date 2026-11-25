# Heavy Gear II (1999) — Complete Steam Deck & Linux Guide

This repository contains the complete configuration, reverse-engineered binary patches, audio DLLs, input bindings, and Steam Deck controller profile to run **Heavy Gear II (1999)** natively on the **Steam Deck (SteamOS / Proton 9)** with full 3D hardware graphics, twin-stick controller movement, responsive mouse aiming, full audio, and CD bypass.

---

## What Issues Were Solved

1. **Game Terminated Abruptly / CD Check**:
   - `Heavy Gear 2.exe` patched at RVA `0x4015b0` to bypass hardware CD-ROM polling and map drive `D:`.
   - `shell.dll` patched at RVA `0x100ef54a` to bypass runtime CD media checks and No-CD modal dialogs.
2. **"No Ear DLLs installed" on 3D Mission Launch**:
   - Fixed by bundling native Miles Sound System / Aureal Ear audio libraries (`earias.dll`, `earpds.dll`, `config.ear`) and dummying `earmusf.exe`.
3. **Stuck at 100% Mission Loading Screen (Stack Overflow)**:
   - Root Cause: Duplicate binding action names in `bindings.def` caused `hg2sim.dll` to append a control node to itself, producing a circular linked list. At mission start, `0x10136B40` recursively traversed the list, triggering `EXCEPTION_STACK_OVERFLOW (0xC00000FD)`.
   - Fix: Completely deduplicated and cleaned `bindings.def` and `Defaults.dft` using exact Proton X11 keysym identifiers.
4. **Left Stick / WASD Movement Inoperative in 3D Missions**:
   - Root Cause: In Proton/Wine's DirectInput keyboard driver, `EnumObjects` enumerates standard keys (`dwOfs < 0x80`, e.g. `0x11` for `W`) followed by extended duplicate keys (`dwOfs >= 0x80`, e.g. `0x91`). `hg2sim.dll`'s `0x10135D60` inserted enumerated keys at the head of a singly-linked list, causing extended dummy keys to shadow real keys. Wine's `GetDeviceState` sets byte `0x11` on `W`, while `hg2sim.dll` polled byte `0x91` (always `0`).
   - Fix: Patched `hg2sim.dll` at RVA `0x10136E9C` to test `dwOfs & 0x80` and skip all extended scancodes. Only true DirectInput keys are registered.
5. **Modern Steam Deck Controller Layout**:
   - Dedicated Neptune template with Twin-Stick movement (Left Stick WASD + Right Stick / Trackpad Mouse Look), Triggers for Primary/Secondary fire, Bumpers for Jump Jets and Weapon Cycle, Face buttons for Jump/Crouch/Targeting, D-pad for Throttle & Sidestep, and Back Grips for Full Stop (L4) and Torso Center (L5).

---

## Quick Installation on Steam Deck

### 1. Game Files
If you need the base game files, you can acquire them from:
- **[MyAbandonware — Heavy Gear II](https://www.myabandonware.com/game/heavy-gear-ii-a79)**

Extract or install the game files to your Steam Deck directory (e.g. `/home/deck/Games/Heavy Gear 2/`).

---

### 2. One-Command 100% Automated Setup (Recommended)

`install_deck.sh` completely automates the entire installation, patching, and Steam library registration:

- **Option A: Install directly from an ISO image**
  ```bash
  git clone https://github.com/khoanguye/heavy-gear-2-steamdeck.git
  cd heavy-gear-2-steamdeck
  chmod +x install_deck.sh
  ./install_deck.sh ~/Downloads/HeavyGear2.iso
  ```

- **Option B: Install from an existing/extracted game folder**
  ```bash
  ./install_deck.sh "/home/deck/Games/Heavy Gear 2"
  ```

#### What `install_deck.sh` does automatically:
1. **Extracts ISO / Archive**: Uses built-in `7z`/`bsdtar` to unpack the game files.
2. **Deploys Engine Patches**: Installs `hg2sim.dll` (WASD fix), `Heavy Gear 2.exe` & `shell.dll` (CD bypass), and audio DLLs.
3. **Registers in Steam Library**: Automatically writes `Heavy Gear II` into Steam's `shortcuts.vdf` database with icon.
4. **Locks Proton 9 Compatibility**: Automatically writes Steam's compatibility tool mapping in `config.vdf`.
5. **Configures Launch Options**: Automatically sets `PROTON_USE_WINED3D=1 %command%`.
6. **Applies Controller Profile**: Installs and activates the dedicated Twin-Stick Neptune layout in Steam.

*After running the script, simply switch back to Steam Game Mode (or restart Steam) and click Play!*

---

### 3. Manual Installation (Optional / Alternative)
If you prefer configuring Steam manually:
1. Copy all files from `patches/` into your `/home/deck/Games/Heavy Gear 2/` directory.
2. Copy `patches/controller_neptune_heavygear2.vdf` to:
   ```bash
   /home/deck/.local/share/Steam/controller_base/templates/controller_neptune_heavygear2.vdf
   ```
3. In Steam Desktop mode, click **Games -> Add a Non-Steam Game** -> Select `Heavy Gear 2.exe`.
4. Right-click Heavy Gear 2 in Steam -> **Properties**:
   - **Compatibility**: Check "Force the use of a specific compatibility tool" -> Select **Proton 9.0**.
   - **Launch Options**: Enter `PROTON_USE_WINED3D=1 %command%`.
5. In Game Mode -> Controller Settings -> Templates -> Select **"Heavy Gear II Steam Deck Layout"**.

---

## In-Game Scaling (Menu & 3D)

Because Heavy Gear II's 2D menus render at 640x480:
1. Press the **`...` (Quick Access)** button on the Steam Deck.
2. Select the **Performance (battery icon)** menu.
3. Under **Scaling Mode**, select **`Fit`** (preserves 4:3 aspect ratio) or **`Fill`** (full 16:10).
4. Under **Scaling Filter**, select **`FSR`** (Sharpness: `2`–`5`) for crisp menu text.

---

## Default Controls Mapping

| Steam Deck Input | Action | In-Game Binding |
| :--- | :--- | :--- |
| **Left Stick** | Mech Walk / Turn | `W`, `S`, `A`, `D` |
| **Left Stick Click (L3)** | Toggle Wheels / Treads | `V` |
| **Right Stick / Trackpad** | Aim Reticle / Torso Twist | Mouse Look |
| **Right Stick Click (R3)** | Target Nearest Enemy | `R` |
| **Right Trigger** | Primary Weapon Fire | Left Mouse Button |
| **Left Trigger** | Weapon Cycle | Right Mouse Button |
| **Left Bumper (LB)** | Jump Jets | `Left Shift` |
| **Right Bumper (RB)** | Change Weapon | `B` |
| **Button A** | Jump | `Space` |
| **Button B** | Crouch | `Left Control` |
| **Button X** | Target Nearest Enemy | `R` |
| **Button Y** | Cycle Target | `T` |
| **D-Pad Up / Down** | Increase / Decrease Throttle | `=`, `-` |
| **D-Pad Left / Right** | Sidestep Left / Right | `Q`, `E` |
| **Back Grip L4** | Full Stop | `X` |
| **Back Grip L5** | Center Torso to Legs | `C` |
| **Back Grip R4** | Throw Grenade | `G` |
| **Back Grip R5** | Tactical Map | `Tab` |
| **View Button** | Mission Objectives | `O` |
| **Menu Button** | In-Game Menu / Options | `Escape` |
