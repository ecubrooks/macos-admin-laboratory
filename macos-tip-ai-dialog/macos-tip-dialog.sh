#!/bin/zsh

###############################################################################
# macOS Tip Dialog (SwiftDialog + Apple Intelligence)
#
# Purpose:
#   Displays a dynamic macOS tip to the user using SwiftDialog. Tips are
#   generated via `/usr/bin/fm` CLI OR swift leveraging Apple Intelligence 
#   (FoundationModels) with a fallback message if generation fails.
#
# Behavior:
#   - Script asks /usr/bin/fm (27.x+) or swift to generate a random macOS tip
#   - Falls back to a static tip if AI output is unavailable
#   - Adjusts UI (icon, banner title, color) based on content
#   - Presents macOS Tip via SwiftDialog
#
# Author: ecburooks 
# Date: May 2026, September 2026
###############################################################################

# Path to SwiftDialog binary (assumes it is already installed)
swiftdialog="/usr/local/bin/dialog"

# Path to the Foundation Models command-line tool 
fmBinary="/usr/bin/fm"

# Path to your Swift AI helper script that generates the macOS tip
swiftAIHelper="/Library/Application Support/Swift/MacTipAI.swift"

# Ensure SwiftDialog exists and is executable before continuing
if [[ ! -x "$swiftdialog" ]]; then
    echo "SwiftDialog not found."
    exit 1
fi

# Function accept fm license prompt. 
acceptFMLicense() {
    if [[ ! -x "/usr/bin/expect" ]]; then
        echo "The expect command is unavailable; unable to automate the fm license prompt."
        return 1
    fi

    /usr/bin/expect <<'EXPECT_SCRIPT'
set timeout 30
log_user 0

spawn /usr/bin/fm license

expect {
    -re {DO YOU AGREE TO THESE TERMS\?} {
        send -- "yes\r"
        exp_continue
    }
    eof {
        catch wait result
        exit [lindex $result 3]
    }
    timeout {
        exit 1
    }
}
EXPECT_SCRIPT
}

# Generate a macOS tip.
generateMacOSTip() {
  local tipCategories=(
    "Finder"
    "keyboard shortcuts"
    "security and privacy"
    "network and Wi-Fi troubleshooting"
    "macOS productivity"
    "software updates"
  )
  
  local category="${tipCategories[$((RANDOM % ${#tipCategories[@]} + 1))]}"
  
  "$fmBinary" respond "
Act as an IT support assistant for macOS users.

Create exactly one helpful macOS tip about:
${category}

Requirements:
- Fewer than 45 words
- Appropriate for everyday users
- Give a specific action the user can perform
- Do not mention artificial intelligence
- Do not include a heading or introduction
- Return only the tip

Variation ID: $(uuidgen)
Current time: $(date)" 2>/dev/null
}

# Previous generated tip
lastTipFile="/var/tmp/com.tip.macos.last"
lastTip=""

# FM generation results, prevent fm from thinking it already was succesful
macOStip=""
fmExitCode=1

if [[ -r "$lastTipFile" ]]; then
  lastTip=$(cat "$lastTipFile")
fi

# Accept the Foundation Models (fm) terms if prompted, then attempt tip generation.
# Compare the generated tip with the previous tip to help prevent duplicates.
if [[ -x "$fmBinary" ]]; then
	if acceptFMLicense; then
		echo "Foundation Models license is accepted."
    
    # Maximum generation attempts for loop
    maxAttempts=3
    
    for (( attempt=1; attempt<=maxAttempts; attempt++ )); do
      macOStip=$(generateMacOSTip)
      fmExitCode=$?
      
      if (( fmExitCode == 0 )); then
        if [[ -n "$macOStip" ]]; then
          if [[ "$macOStip" != "$lastTip" ]]; then
            break
          else
            echo "Generated tip repeated the previous tip. Attempt $attempt of $maxAttempts."
          fi
        fi
      else
        echo "Tip creation failed. Attempt $attempt of $maxAttempts."
      fi
      
      macOStip=""
    done
    
	else
		echo "Unable to verify or accept the Foundation Models license."
	fi
else
    echo "Foundation Models command-line tool not found at $fmBinary."
fi

if [[ -n "$macOStip" ]]; then
    echo "$macOStip" > "$lastTipFile"
fi

# Fallback if fm fails or returns empty output
if [[ -z "$macOStip" ]]; then

    # Confirm that a usable Swift compiler is available
    swiftPath=$(/usr/bin/xcrun --find swift 2>/dev/null)

	# Execute Swift helper to generate a tip
    if [[ -n "$swiftPath" && -x "$swiftPath" ]]; then
        # Execute Swift helper to generate a tip
        macOStip=$("$swiftPath" "$swiftAIHelper" 2>/dev/null)
        echo "Used Swift service"
    else
        echo "Swift is unavailable. Xcode Command Line Tools are required."
    fi

   # Fallback tip if Swift/AI fails or returns empty output
    if [[ -z "$macOStip" ]]; then
        macOStip="macOS Tip: Use Command + Space to open Spotlight and quickly find apps, files, and settings."
        echo "Used default tip"
    fi

else
    echo "Used macOS FM service"
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
