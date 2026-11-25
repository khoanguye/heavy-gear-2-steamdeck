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

### 2. Apply Community Fix Package

#### Automated Method (Recommended):
`install_deck.sh` works with **both an ISO file or an already extracted folder**:

- **From an ISO / Archive directly:**
  ```bash
  chmod +x install_deck.sh
  ./install_deck.sh ~/Downloads/HeavyGear2.iso
  ```
  *(Uses SteamOS built-in `7z`/`bsdtar` to automatically extract the ISO into `/home/deck/Games/Heavy Gear 2/` and apply all patches).*

- **From an already extracted directory:**
  ```bash
  chmod +x install_deck.sh
  ./install_deck.sh "/home/deck/Games/Heavy Gear 2"
  ```
This automatically extracts the game (if an ISO is provided), copies patched binaries, audio DLLs, input definitions, configuration files, and installs the Steam Deck controller template to Steam's templates directory.

#### Manual Method:
Copy the files from the `patches/` folder into your `/home/deck/Games/Heavy Gear 2/` directory:
- `Heavy Gear 2.exe` (CD check bypass)
- `shell.dll` (Engine & CD bypass)
- `hg2sim.dll` (DirectInput scancode fix for WASD movement)
- `Dxver.dll` (DirectX 6.1 bypass)
- `earias.dll`, `earpds.dll`, `config.ear`, `earmusf.exe` (Audio stack)
- `bindings.def` and `Shell/bindings/Defaults.dft` (Cleaned Proton keybindings)
- `HG2.cfg` (Default configuration)

And copy `patches/controller_neptune_heavygear2.vdf` to:
```bash
/home/deck/.local/share/Steam/controller_base/templates/controller_neptune_heavygear2.vdf
```

---

### 3. Steam Configuration (Game Mode)
1. In Steam Desktop mode (or via Steam client), add `Heavy Gear 2.exe` as a **Non-Steam Game**.
2. In Steam Game Properties -> **Compatibility**:
   - Check **"Force the use of a specific Steam Play compatibility tool"**.
   - Select **Proton 9.0**.
3. In Steam Game Properties -> **Launch Options**:
   ```bash
   PROTON_USE_WINED3D=1 %command%
   ```
4. Return to Game Mode -> Heavy Gear 2 -> Controller Settings -> Templates -> Select **"Heavy Gear II Steam Deck Layout"**.

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
