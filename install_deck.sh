#!/usr/bin/env bash
# ==============================================================================
# Heavy Gear II — Automated Steam Deck Installer & Patch Script
# ==============================================================================
set -euo pipefail

SOURCE_INPUT="${1:-}"
GAME_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$SCRIPT_DIR/patches"
STEAM_TEMPLATE_DIR="$HOME/.local/share/Steam/controller_base/templates"

echo "=== Heavy Gear II Steam Deck Setup ==="

# Check if input is an ISO or archive file
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
    # Default path
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

echo "--> Copying patched binaries, audio DLLs, and configurations..."
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

echo "--> Installing Steam Deck Controller Profile..."
mkdir -p "$STEAM_TEMPLATE_DIR"
if [ -f "$PATCH_DIR/controller_neptune_heavygear2.vdf" ]; then
    cp -f "$PATCH_DIR/controller_neptune_heavygear2.vdf" "$STEAM_TEMPLATE_DIR/controller_neptune_heavygear2.vdf"
    echo "    Controller profile installed to Steam templates."

    # Automatically set as active layout for any detected Steam user profile
    for user_cfg in "$HOME/.local/share/Steam/steamapps/common/Steam Controller Configs"/*/config; do
        if [ -d "$user_cfg" ]; then
            for title in "Heavy Gear 2" "heavy gear 2" "Heavy Gear II" "heavy gear ii"; do
                mkdir -p "$user_cfg/$title"
                cp -f "$PATCH_DIR/controller_neptune_heavygear2.vdf" "$user_cfg/$title/controller_neptune.vdf"
            done
            echo "    Automatically set as active controller profile for Steam."
        fi
    done
fi

# Link to SD card if present
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
echo "=== Installation Completed Successfully! ==="
echo ""
echo "Next steps in Steam (Game Mode):"
echo "  1. Add 'Heavy Gear 2.exe' as a Non-Steam Game."
echo "  2. Go to Properties -> Compatibility -> Check 'Force the use of a specific Steam Play compatibility tool' -> Choose 'Proton 9.0'."
echo "  3. Go to Properties -> Launch Options -> Enter:"
echo "     PROTON_USE_WINED3D=1 %command%"
echo "  4. Go to Controller Settings -> Templates -> Select 'Heavy Gear II Steam Deck Layout'."
echo "  5. In-Game: Press '...' button -> Performance -> Set Scaling Mode to 'Fit' and Filter to 'FSR'."
echo ""
