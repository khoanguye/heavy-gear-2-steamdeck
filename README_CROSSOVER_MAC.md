# Heavy Gear II (1999) CrossOver Mac Configuration & Patches

This directory contains the complete CrossOver Mac configuration, reverse-engineered binary patches, and launcher scripts required to run **Heavy Gear II** smoothly on Apple Silicon with 3D hardware graphics, full sound, CD verification bypass, responsive mouse input, and seamless launching from either the terminal launcher or the CrossOver Mac GUI.

---

## Directory Structure
- `launch_heavy_gear_2.sh`: Standalone launcher script executing the game inside a 640x480 Wine virtual desktop (`explorer.exe /desktop=HG2,640x480`).
- `bottle_config/`: CrossOver bottle registry exports and launcher configurations:
  - `user.reg`:
    - `[Software\Wine\Explorer\Desktops]` configured with `"Default"="640x480"` and `"HG2"="640x480"`.
    - `[Software\Wine\DirectInput]` configured with `MouseWarpOverride="disable"`.
  - `system.reg`:
    - `[Software\Wine\Drives]` configured with `"d:"="cdrom"`.
  - `Heavy+Gear+2.lnk`: CrossOver desktop menu launcher script configured for 640x480 virtual desktop.
  - `cxbottle.conf`: Bottle configuration metadata.
- `patches/`: Patched binaries and configuration:
  - `Heavy Gear 2.exe`: CD check bypass (RVA `0x4015b0` sets CD letter to `D:` and CD count to `1`).
  - `shell.dll`: All engine fixes (CD verification bypass, dialog suppression, 16-bit color bypass, critical section NOPs, video skip, resource trampoline, mouse cursor visibility).
  - `Dxver.dll`: DirectX 6.1 version bypass.
  - `earmusf.exe`: Replaced with Wine `cxdummy.exe` to silence audio mixer setup crash.
  - `HG2.cfg`: Native configuration (`ScreenWidth 640`, `ScreenHeight 480`, `ScreenBpp 16`, `FullScreen-Mode 1`, `DisplayDriver 1`).

---

## Why External Wrappers Failed

1. **`cnc-ddraw` (D3D Init Error)**:
   - `cnc-ddraw` is exclusively a 2D DirectDraw wrapper.
   - When transitioning from the 2D menu (`shell.dll`) to the 3D simulation engine (`hg2sim.dll`) to start a campaign mission, the game calls `IDirectDraw::QueryInterface(IID_IDirect3D3)`. `cnc-ddraw` does not implement Direct3D 3, returning `E_NOINTERFACE` and causing the "Error Initializing d3d" popup.

2. **Direct Execution Without Virtual Desktop (Black Screen)**:
   - macOS Liquid Retina displays on Apple Silicon do not support hardware display mode switching to 640x480 16-bit color.
   - Without a 640x480 virtual desktop (`explorer.exe /desktop=HG2,640x480`), Wine attempts a physical display mode change which deadlocks `wined3d_cs` and leaves a black window.
   - Wine's built-in `ddraw.dll` inside the 640x480 virtual desktop provides both DirectDraw and Direct3D 3 acceleration natively without display switch deadlocks.

---

## Summary of Reverse-Engineered Binary Patches

### 1. `Heavy Gear 2.exe`
- **CD-ROM Drive Check Bypass (File Offset `0x9b0` / RVA `0x4015b0`)**:
  - Replaced scan routine with:
    ```x86
    mov byte ptr [0x404468], 0x44    ; 'D'
    mov dword ptr [0x40446c], 1      ; count = 1
    mov al, 0x44                     ; return 'D'
    ret
    ```
  - Machine code: `c6 05 68 44 40 00 44 c7 05 6c 44 40 00 01 00 00 00 b0 44 c3`.

### 2. `shell.dll`
- **Runtime CD Verification & "No CD found" Modal Bypass**:
  - **File Offset `0xee94a` (RVA `0x100ef54a` - `CheckForCD`)**:
    Sets `[this + 0x58]` drive letter to `'D'`, CD count to `1`, and returns `'D'` (`8b 41 58 85 c0 74 0a c6 00 44 c7 40 04 01 00 00 00 b0 44 c3`).
  - **File Offset `0xee9be` (RVA `0x100ef5be` - `tln.dat` CD Media Check)**:
    Sets `[[this + 0x58] + 0x1c]` to `1` and returns `1` (`8b 41 58 85 c0 74 07 c7 40 1c 01 00 00 00 b8 01 00 00 00 c3`).
  - **File Offset `0x101bbd` (RVA `0x101027bd` - Modal Dialog Branch)**:
    Patched `je 0x101027c5; cmp ...; jne 0x101027e0` to `jmp 0x101027e0` (`eb 21 90 90 90 90 90 90`), bypassing the string `0xCC` ("No CD found. Please insert HG2 CD") modal and error abort.
- **Mouse Cursor Visibility**:
  - **Offset `0x49006` (RVA `0x10049c06`)**: Patched `0x75 0x10` (`jne`) to `0xeb 0x10` (`jmp`), forcing `ShowCursor(1)` display loop on `WM_SETCURSOR`.
  - **Offset `0x4920f`**: Patched 14-byte `ShowCursor(0)` loop to `eb 0c` + NOPs to prevent hiding the Windows cursor.
  - **Offset `0x5988f`**: Patched 14-byte `ShowCursor(0)` loop to `eb 0c` + NOPs to prevent hiding the Windows cursor during transitions.
- **DirectDraw Surface Lock Prevention (Offset `0xed664` / RVA `0x100ee264`)**:
  - Reverted `0x1b4` to `0x1bc` (`mov edx, [ecx + 0x1bc]`).
  - Combined with trampoline at `0x100ee289` (`jecxz 0x100ee2c2`), prevents `OutputFP->ReleaseDC("OUTPUTFP")` from failing and locking the frontbuffer.
- **DirectX & Color Depth Compatibility**:
  - **Offset `0xea67a`**: Patched `0x74` -> `0xeb` (bypasses `GetDeviceCaps(hDC, BITSPIXEL) == 16`).
  - **Offset `0x0ea6ef`**: Patched to jump over "Unknown Error Detected" popups.
  - **Offset `0x0595e4`**: Bypasses 16-bit 565 pixel format mismatch.
  - **Offset `0x0643a1`**: Forces method 0x6c return value to 0.
  - **Offset `0x101cb1`**: Skips `title.avi` (Indeo 5.0) playback.
  - **Offsets `0x023ae0` & `0x023c32`**: Rosetta critical section crash bypass.

---

## How to Run
Launch the game either:
1. **Via the launcher script**:
   ```bash
   /Users/khoa/launch_heavy_gear_2.sh
   ```
2. **Directly from CrossOver**:
   - Double-click the **Heavy Gear 2** icon in CrossOver or run `~/Applications/CrossOver/Heavy Gear 2.app`.
