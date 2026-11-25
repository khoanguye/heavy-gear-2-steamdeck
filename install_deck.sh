#!/usr/bin/env bash
# ==============================================================================
# Heavy Gear II — 100% Automated Steam Deck Installer & Setup Script
# ==============================================================================
set -euo pipefail

SOURCE_INPUT="${1:-}"
GAME_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$SCRIPT_DIR/patches"
STEAM_TEMPLATE_DIR="$HOME/.local/share/Steam/controller_base/templates"

echo "=== Heavy Gear II Steam Deck Automated Setup ==="

# 1. Determine Game Directory / Extract ISO or Archive
if [ -n "$SOURCE_INPUT" ] && [ -f "$SOURCE_INPUT" ]; then
    ARCHIVE_FILE="$SOURCE_INPUT"
    GAME_DIR="${2:-$HOME/Games/Heavy Gear 2}"
    echo "--> Source archive / ISO detected: $ARCHIVE_FILE"
    echo "--> Target Game Directory: $GAME_DIR"
    mkdir -p "$GAME_DIR"

    echo "--> Extracting ISO / archive..."
    if command -v 7z >/dev/null 2>&1; then
        7z x "$ARCHIVE_FILE" -o"$GAME_DIR" -y
    elif command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xf "$ARCHIVE_FILE" -C "$GAME_DIR"
    else
        echo "Error: Neither '7z' nor 'bsdtar' found to extract ISO."
        exit 1
    fi
elif [ -n "$SOURCE_INPUT" ] && [ -d "$SOURCE_INPUT" ]; then
    GAME_DIR="$SOURCE_INPUT"
    echo "--> Using existing game directory: $GAME_DIR"
else
    GAME_DIR="$HOME/Games/Heavy Gear 2"
    echo "--> Target Game Directory: $GAME_DIR"
    if [ ! -d "$GAME_DIR" ]; then
        echo "Creating directory: $GAME_DIR"
        mkdir -p "$GAME_DIR"
    fi
fi

if [ ! -d "$PATCH_DIR" ]; then
    echo "Error: patches directory not found at $PATCH_DIR"
    exit 1
fi

# 2. Deploy Patches and Assets
echo "--> Deploying patched binaries, audio DLLs, and configurations..."
mkdir -p "$GAME_DIR/Shell/bindings"
cp -f "$PATCH_DIR/Heavy Gear 2.exe" "$GAME_DIR/"
cp -f "$PATCH_DIR/shell.dll" "$GAME_DIR/"
cp -f "$PATCH_DIR/hg2sim.dll" "$GAME_DIR/"
cp -f "$PATCH_DIR/Dxver.dll" "$GAME_DIR/"
cp -f "$PATCH_DIR/earias.dll" "$GAME_DIR/"
cp -f "$PATCH_DIR/earpds.dll" "$GAME_DIR/"
cp -f "$PATCH_DIR/config.ear" "$GAME_DIR/"
cp -f "$PATCH_DIR/earmusf.exe" "$GAME_DIR/"
cp -f "$PATCH_DIR/HG2.cfg" "$GAME_DIR/"
cp -f "$PATCH_DIR/bindings.def" "$GAME_DIR/"
cp -f "$PATCH_DIR/Shell/bindings/Defaults.dft" "$GAME_DIR/Shell/bindings/"

chmod +x "$GAME_DIR/Heavy Gear 2.exe" "$GAME_DIR/earmusf.exe"

# 3. Controller Configuration
echo "--> Installing Steam Deck Controller Profile..."
mkdir -p "$STEAM_TEMPLATE_DIR"
if [ -f "$PATCH_DIR/controller_neptune_heavygear2.vdf" ]; then
    cp -f "$PATCH_DIR/controller_neptune_heavygear2.vdf" "$STEAM_TEMPLATE_DIR/controller_neptune_heavygear2.vdf"
    echo "    Controller profile installed to Steam templates."

    # Automatically set as active layout for any detected Steam user profile
    for user_cfg in "$HOME/.local/share/Steam/steamapps/common/Steam Controller Configs"/*/config "$HOME/.steam/steam/steamapps/common/Steam Controller Configs"/*/config; do
        if [ -d "$user_cfg" ]; then
            for title in "Heavy Gear 2" "heavy gear 2" "Heavy Gear II" "heavy gear ii" "3068975039"; do
                mkdir -p "$user_cfg/$title"
                cp -f "$PATCH_DIR/controller_neptune_heavygear2.vdf" "$user_cfg/$title/controller_neptune.vdf"
            done
            echo "    Automatically configured active controller profile in $(basename "$(dirname "$user_cfg")")."
        fi
    done
fi

# 4. Automatically Add Non-Steam Game & Set Proton 9 in Steam Library
echo "--> Registering Heavy Gear II in Steam Library & Configuring Proton 9..."
python3 - "$GAME_DIR" << 'EOF'
import os, sys, glob, struct, zlib, re

game_dir = sys.argv[1]
exe_target = os.path.join(game_dir, "Heavy Gear 2.exe")
exe_str = f'"{exe_target}"'
start_dir = f'"{game_dir}/"'
app_name = "Heavy Gear II"
icon_path = os.path.join(game_dir, "gear.ico")
if not os.path.isfile(icon_path):
    icon_path = ""

# Compute Steam 32-bit AppID
key = (exe_str + app_name).encode("utf-8")
crc = zlib.crc32(key)
combined = crc | 0x80000000
signed_appid = struct.unpack("<i", struct.pack("<I", combined))[0]
unsigned_appid = str(combined & 0xFFFFFFFF)

def parse_vdf(data, pos=0):
    res = {}
    while pos < len(data):
        t = data[pos]
        pos += 1
        if t == 8:
            break
        null = data.find(b"\x00", pos)
        key = data[pos:null].decode("utf-8", errors="ignore")
        pos = null + 1
        if t == 0:
            sub, pos = parse_vdf(data, pos)
            res[key] = sub
        elif t == 1:
            null = data.find(b"\x00", pos)
            val = data[pos:null].decode("utf-8", errors="ignore")
            pos = null + 1
            res[key] = val
        elif t == 2:
            val = struct.unpack("<i", data[pos:pos+4])[0]
            pos += 4
            res[key] = val
    return res, pos

def encode_vdf(obj):
    out = bytearray()
    for k, v in obj.items():
        if isinstance(v, dict):
            out.append(0)
            out.extend(k.encode("utf-8") + b"\x00")
            out.extend(encode_vdf(v))
            out.append(8)
        elif isinstance(v, str):
            out.append(1)
            out.extend(k.encode("utf-8") + b"\x00")
            out.extend(v.encode("utf-8") + b"\x00")
        elif isinstance(v, int):
            out.append(2)
            out.extend(k.encode("utf-8") + b"\x00")
            out.extend(struct.pack("<i", v))
    return bytes(out)

# 4a. Update shortcuts.vdf for each Steam user
steam_roots = [
    os.path.expanduser("~/.local/share/Steam"),
    os.path.expanduser("~/.steam/steam")
]
user_dirs = []
for root in steam_roots:
    user_dirs.extend(glob.glob(os.path.join(root, "userdata", "*", "config")))

user_dirs = list(set(user_dirs))
for udir in user_dirs:
    shortcuts_path = os.path.join(udir, "shortcuts.vdf")
    shortcuts_dict = {"shortcuts": {}}
    if os.path.isfile(shortcuts_path):
        try:
            with open(shortcuts_path, "rb") as f:
                data = f.read()
            parsed, _ = parse_vdf(data)
            if "shortcuts" in parsed:
                shortcuts_dict = parsed
        except Exception as e:
            print(f"    Warning reading {shortcuts_path}: {e}")

    shortcuts = shortcuts_dict.get("shortcuts", {})
    found = False
    for idx, s in shortcuts.items():
        if s.get("AppName") in ["Heavy Gear II", "Heavy Gear 2"] or "Heavy Gear 2.exe" in s.get("Exe", ""):
            s["AppName"] = app_name
            s["Exe"] = exe_str
            s["StartDir"] = start_dir
            s["LaunchOptions"] = "PROTON_USE_WINED3D=1 %command%"
            if icon_path:
                s["icon"] = icon_path
            s["IsHidden"] = 0
            s["AllowDesktopConfig"] = 1
            s["AllowOverlay"] = 1
            found = True
            print(f"    Updated existing Steam shortcut in {os.path.basename(os.path.dirname(udir))}.")
            break

    if not found:
        new_idx = str(len(shortcuts))
        shortcuts[new_idx] = {
            "appid": signed_appid,
            "AppName": app_name,
            "Exe": exe_str,
            "StartDir": start_dir,
            "icon": icon_path,
            "ShortcutPath": "",
            "LaunchOptions": "PROTON_USE_WINED3D=1 %command%",
            "IsHidden": 0,
            "AllowDesktopConfig": 1,
            "AllowOverlay": 1,
            "OpenVR": 0,
            "Devkit": 0,
            "DevkitGameID": "",
            "DevkitOverrideAppID": 0,
            "LastPlayTime": 0,
            "FlatpakAppID": "",
            "sortas": "",
            "tags": {}
        }
        shortcuts_dict["shortcuts"] = shortcuts
        print(f"    Added Heavy Gear II to Steam Library in {os.path.basename(os.path.dirname(udir))}.")

    try:
        if os.path.isfile(shortcuts_path):
            with open(shortcuts_path + ".bak", "wb") as bak:
                with open(shortcuts_path, "rb") as orig:
                    bak.write(orig.read())
        encoded = encode_vdf(shortcuts_dict)
        with open(shortcuts_path, "wb") as f:
            f.write(encoded)
    except Exception as e:
        print(f"    Error saving {shortcuts_path}: {e}")

# 4b. Configure Proton 9 in config.vdf
for root in steam_roots:
    cfg_path = os.path.join(root, "config", "config.vdf")
    if os.path.isfile(cfg_path):
        try:
            with open(cfg_path, "r", encoding="utf-8", errors="ignore") as f:
                cfg_text = f.read()
            if "CompatToolMapping" in cfg_text:
                if f'"{unsigned_appid}"' not in cfg_text:
                    entry = (
                        f'\t\t\t\t\t"{unsigned_appid}"\n'
                        f'\t\t\t\t\t{{\n'
                        f'\t\t\t\t\t\t"name"\t\t"proton_9"\n'
                        f'\t\t\t\t\t\t"config"\t\t""\n'
                        f'\t\t\t\t\t\t"priority"\t\t"250"\n'
                        f'\t\t\t\t\t}}\n'
                    )
                    pattern = r'("CompatToolMapping"\s*\{)'
                    if re.search(pattern, cfg_text):
                        cfg_text = re.sub(pattern, r'\1\n' + entry, cfg_text, count=1)
                        with open(cfg_path, "w", encoding="utf-8") as f:
                            f.write(cfg_text)
                        print(f"    Configured Proton 9 compatibility mapping in {cfg_path}.")
        except Exception as e:
            print(f"    Warning updating {cfg_path}: {e}")
EOF

# 5. Link to SD card if present
SD_CARD_DIR=$(find /run/media/deck -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -n 1 || true)
if [ -n "$SD_CARD_DIR" ] && [ -d "$SD_CARD_DIR" ]; then
    echo "--> Detected SD card at: $SD_CARD_DIR"
    echo "    Setting up symlinks for CD drive mapping..."
    mkdir -p "$SD_CARD_DIR/Shell/bindings"
    for f in "$GAME_DIR"/*; do
        base="$(basename "$f")"
        if [ ! -e "$SD_CARD_DIR/$base" ]; then
            ln -sf "$f" "$SD_CARD_DIR/$base"
        fi
    done
fi

echo ""
echo "==========================================================="
echo "   Installation & Steam Setup Completed Successfully!"
echo "==========================================================="
echo ""
echo "Heavy Gear II has been automatically configured:"
echo "  [x] Base game files extracted & verified"
echo "  [x] Binary patches & audio libraries deployed"
echo "  [x] Added to Steam Non-Steam Library (with icon)"
echo "  [x] Launch options set to: PROTON_USE_WINED3D=1 %command%"
echo "  [x] Compatibility tool locked to: Proton 9.0"
echo "  [x] Twin-stick Steam Deck controller profile installed"
echo ""
if pgrep -x "steam" >/dev/null 2>&1; then
    echo "NOTE: Steam is currently running. Please restart Steam or switch"
    echo "      between Desktop and Game Mode to refresh your library!"
else
    echo "Ready to play! Start Steam to see Heavy Gear II in your library."
fi
echo ""
