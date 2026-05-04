#!/bin/zsh

###############################################################################
# macOS Tip Dialog (SwiftDialog + Apple Intelligence)
#
# Purpose:
#   Displays a dynamic macOS tip to the user using SwiftDialog. Tips are
#   generated via a Swift helper leveraging Apple Intelligence (FoundationModels),
#   with a fallback message if generation fails.
#
# Behavior:
#   - SwiftDialog asks swift to generate a random macOS tip
#   - Falls back to a static tip if AI output is unavailable
#   - Adjusts UI (icon, banner title, color) based on content
#   - Presents macOS Tip via SwiftDialog
#
# Author: ecburooks 
# Date: May 2026
###############################################################################

# Path to SwiftDialog binary (assumes it is already installed)
swiftdialog="/usr/local/bin/dialog"

# Path to your Swift AI helper script that generates the macOS tip
swiftAIHelper="/Library/Application Support/Swift/MacTipAI.swift"

# Ensure SwiftDialog exists and is executable before continuing
if [[ ! -x "$swiftdialog" ]]; then
    echo "SwiftDialog not found."
    exit 1
fi

# Execute Swift helper to generate a tip
macOStip=$(/usr/bin/swift "$swiftAIHelper" 2>/dev/null)

# Fallback tip if Swift/AI fails or returns empty output
if [[ -z "$macOStip" ]]; then
    macOStip="macOS Tip: Use Command + Space to open Spotlight and quickly find apps, files, and settings."
fi

# Default dialog UI values (used if no category match is found)
dialogTitle="macOS Tip"
dialogIcon="SF=lightbulb"
bannerTitle="Helpful macOS Tip"
bannerImage="colour=#2F80ED"

# Lowercase tip text for category matching
tipCheck="${macOStip:l}"

# Categorize the tip based on keywords to adjust UI (icon + banner)
if [[ "$tipCheck" == *"security"* || "$tipCheck" == *"password"* || "$tipCheck" == *"privacy"* || "$tipCheck" == *"keychain"* ]]; then
  dialogIcon="SF=lock.shield"
  bannerTitle="Security Tip"
  bannerImage="colour=#008000"   # Green = security
  
elif [[ "$tipCheck" == *"finder"* || "$tipCheck" == *"file"* || "$tipCheck" == *"folder"* ]]; then
  dialogIcon="SF=folder"
  bannerTitle="Finder Tip"
  bannerImage="colour=#0000FF"   # Blue = navigation
  
elif [[ "$tipCheck" == *"keyboard"* || "$tipCheck" == *"shortcut"* || "$tipCheck" == *"command"* ]]; then
  dialogIcon="SF=keyboard"
  bannerTitle="Keyboard Shortcut"
  bannerImage="colour=#800080"   # Purple = producivity
  
elif [[ "$tipCheck" == *"update"* || "$tipCheck" == *"restart"* || "$tipCheck" == *"software"* ]]; then
  dialogIcon="SF=arrow.triangle.2.circlepath.circle"
  bannerTitle="System Tip"
  bannerImage="colour=#5f5f5f"   # Gray = system
  
elif [[ "$tipCheck" == *"wifi"* || "$tipCheck" == *"wi-fi"* || "$tipCheck" == *"network"* || "$tipCheck" == *"vpn"* ]]; then
  dialogIcon="SF=wifi"
  bannerTitle="Network Tip"
  bannerImage="colour=#FF2800"   # Red = network
  
elif [[ "$tipCheck" == *"dock"* || "$tipCheck" == *"mission control"* || "$tipCheck" == *"stage manager"* ]]; then
  dialogIcon="SF=macwindow"
  bannerTitle="Productivity Tip"
  bannerImage="colour=#FFCC00"   # Yellow = UI
fi

# Display SwiftDialog UI
"$swiftdialog" \
--bannerimage "$bannerImage" \
--bannertitle "$dialogTitle - $bannerTitle" \
--bannerheight 75 \
--width 650 \
--height 320 \
--message "$macOStip" \
--icon "$dialogIcon" \
--iconsize 120 \
--button1text "Got it" \
--moveable \
--ontop