#!/bin/bash

APP_NAME="Ghlass"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DMG_TMP="${APP_NAME}_tmp.dmg"
STAGING_DIR="dmg_staging"

# clean previous build
rm -rf "$APP_BUNDLE" "$DMG_NAME" "$DMG_TMP" "$STAGING_DIR"

# Build the project
echo "Building $APP_NAME..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "Build failed"
    exit 1
fi

# Create App Bundle Structure
echo "Creating App Bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Copy Resources (AppIcon)
ICON_PATH="Sources/Ghlass/Resources/AppIcon.icns"
if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/"
fi

# DMG Volume Icon
DMG_ICON_PATH="docs/VolumeIcon.icns"

# Copy other resources if they exist
RESOURCE_BUNDLE="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -r "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

# Sign the app (Ad-hoc signing)
echo "Signing App..."
codesign --force --deep --sign - "$APP_BUNDLE"

# Prepare DMG Staging
echo "Preparing DMG Staging..."
mkdir -p "$STAGING_DIR"
cp -r "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Copy icon for volume
USE_DMG_ICON=false
if [ -f "$DMG_ICON_PATH" ]; then
    cp "$DMG_ICON_PATH" "$STAGING_DIR/.VolumeIcon.icns"
    USE_DMG_ICON=true
elif [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$STAGING_DIR/.VolumeIcon.icns"
    USE_DMG_ICON=true
fi

if [ "$USE_DMG_ICON" = true ]; then
    # Set the file as invisible
    SetFile -a V "$STAGING_DIR/.VolumeIcon.icns"
fi

# Create temporary read-write DMG
echo "Creating temporary DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$DMG_TMP"

# Set Custom Icon on Volume
if [ "$USE_DMG_ICON" = true ]; then
    echo "Setting DMG Volume Icon..."
    # Create a mount point
    MOUNT_POINT="./mnt_dmg"
    mkdir -p "$MOUNT_POINT"

    # Attach
    hdiutil attach "$DMG_TMP" -mountpoint "$MOUNT_POINT" -readwrite -noverify -noautoopen -quiet

    # Set custom icon attribute on the volume root
    SetFile -a C "$MOUNT_POINT"

    # Detach
    sleep 1
    hdiutil detach "$MOUNT_POINT" -force
    rmdir "$MOUNT_POINT"
fi

# Convert to final compressed DMG
echo "Creating final DMG..."
hdiutil convert "$DMG_TMP" -format UDZO -o "$DMG_NAME"

# Cleanup
rm -rf "$DMG_TMP" "$STAGING_DIR"

echo "Done! App and DMG created."