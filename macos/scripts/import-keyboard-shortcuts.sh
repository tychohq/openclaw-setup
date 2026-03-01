#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Import macOS keyboard shortcuts and preferences from exported plists
# Run this on the Mac Mini after copying the migration folder over
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Importing macOS Keyboard Shortcuts ==="

# System keyboard shortcuts (Mission Control, Spotlight, screenshots, etc.)
if [ -f "$SCRIPT_DIR/com.apple.symbolichotkeys.plist" ]; then
  defaults import com.apple.symbolichotkeys "$SCRIPT_DIR/com.apple.symbolichotkeys.plist"
  echo "[imported] System keyboard shortcuts (com.apple.symbolichotkeys)"
else
  echo "[skipped] com.apple.symbolichotkeys.plist not found"
fi

# Keyboard settings (key repeat, delay, input sources, etc.)
if [ -f "$SCRIPT_DIR/com.apple.Keyboard-Settings.extension.plist" ]; then
  defaults import com.apple.Keyboard-Settings.extension "$SCRIPT_DIR/com.apple.Keyboard-Settings.extension.plist"
  echo "[imported] Keyboard settings (com.apple.Keyboard-Settings.extension)"
else
  echo "[skipped] com.apple.Keyboard-Settings.extension.plist not found"
fi

# Keyboard services (autocorrect, text completion, etc.)
if [ -f "$SCRIPT_DIR/com.apple.keyboardservicesd.plist" ]; then
  defaults import com.apple.keyboardservicesd "$SCRIPT_DIR/com.apple.keyboardservicesd.plist"
  echo "[imported] Keyboard services (com.apple.keyboardservicesd)"
else
  echo "[skipped] com.apple.keyboardservicesd.plist not found"
fi

# Input sources and HIToolbox (keyboard layouts, input methods)
if [ -f "$SCRIPT_DIR/com.apple.HIToolbox.plist" ]; then
  defaults import com.apple.HIToolbox "$SCRIPT_DIR/com.apple.HIToolbox.plist"
  echo "[imported] Input sources (com.apple.HIToolbox)"
else
  echo "[skipped] com.apple.HIToolbox.plist not found"
fi

# Text replacements
if [ -f "$SCRIPT_DIR/com.apple.textInput.keyboardServices.textReplacement.plist" ]; then
  defaults import com.apple.textInput.keyboardServices.textReplacement "$SCRIPT_DIR/com.apple.textInput.keyboardServices.textReplacement.plist"
  echo "[imported] Text replacements"
else
  echo "[skipped] textReplacement plist not found"
fi

# Custom per-app keyboard shortcuts (stored in NSGlobalDomain)
# The setup.sh already writes NSUserDictionaryReplacementItems, but this
# covers NSUserKeyEquivalents (custom menu shortcuts)
echo ""
echo "=== Custom App Menu Shortcuts ==="
defaults write NSGlobalDomain NSUserKeyEquivalents '{
    "Log Out Brenner Spear" = "~^$0";
    "Log Out Brenner Spear\U2026" = "~^$0";
}'
echo "[imported] Global NSUserKeyEquivalents"

echo ""
echo "Done. You may need to log out and back in for all changes to take effect."
echo "Some shortcuts (especially Mission Control/Spaces) require a restart."
