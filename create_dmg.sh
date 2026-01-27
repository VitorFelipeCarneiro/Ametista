#!/bin/bash
set -e

# Configuration
SCHEME_NAME="Projeto.Windows"
APP_NAME_BUILD="Projeto.Windows" # Xcode build output name
FINAL_APP_NAME="Ametista"        # Desired name in DMG
DMG_NAME="Ametista.dmg"

# 1. Build
echo "Building $SCHEME_NAME..."
xcodebuild -scheme "$SCHEME_NAME" -configuration Release build

# 2. Find Built App
# Search for the .app in DerivedData, filtering by Release configuration
APP_PATH=$(find /Users/vitorfelipe/Library/Developer/Xcode/DerivedData -name "$APP_NAME_BUILD.app" | grep "Release" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built app: $APP_NAME_BUILD.app"
    exit 1
fi

echo "Found App at: $APP_PATH"

STAGING_DIR="./dmg_staging"

# 3. Prepare Staging
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

# Copy App and Rename to 'Ametista.app'
echo "Copying app to staging..."
cp -r "$APP_PATH" "$STAGING_DIR/$FINAL_APP_NAME.app"

# 4. Code Sign (Ad-hoc)
# NOTE: Using ad-hoc signing. If Ametista needs specific entitlements (like Zummm), 
# those should be added here. For now, we perform basic deep signing.
echo "Code signing..."
codesign --force --deep -s - "$STAGING_DIR/$FINAL_APP_NAME.app"

# 5. Create DMG Structure
echo "Creating symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

# Create temporary DMG
echo "Creating temporary DMG..."
hdiutil create -volname "$FINAL_APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "tmp.dmg"

# Mount temporary DMG
echo "Mounting DMG..."
MOUNT_POINT=$(hdiutil attach "tmp.dmg" -readwrite -noverify -noautoopen | grep "$FINAL_APP_NAME" | awk '{print $3}')
echo "Mounted at: $MOUNT_POINT"

# Wait a bit for mount
sleep 2

# AppleScript to customize view (Icon View, Drag and Drop)
echo "Customizing view..."
osascript <<EOF
tell application "Finder"
    tell disk "$FINAL_APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 1000, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 144
        update without registering applications
        delay 1
        set position of item "$FINAL_APP_NAME" of container window to {175, 190}
        set position of item "Applications" of container window to {425, 190}
        update without registering applications
        delay 1
    end tell
end tell
EOF

# Unmount
echo "Ejecting..."
hdiutil detach "$MOUNT_POINT"

# Convert to final DMG
echo "Converting to final DMG..."
hdiutil convert "tmp.dmg" -format UDZO -o "$DMG_NAME"

# Cleanup
rm "tmp.dmg"
rm -rf "$STAGING_DIR"

echo "Done! DMG Created: $DMG_NAME"
