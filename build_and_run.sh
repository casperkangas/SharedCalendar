#!/bin/bash

# 1. Build the Swift project
echo "🔨 Building Project..."
swift build

# 2. Define names
APP_NAME="SharedCalendarApp"
BUILD_DIR=".build/debug"
APP_BUNDLE="$APP_NAME.app"

# 3. Create the Mac App folder structure
echo "📂 Creating App Bundle..."
# Clean up previous build to avoid caching issues
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 4. Copy the compiled binary executable into the bundle
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# 5. Copy the Info.plist
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

# 6. Ad-hoc Code Signing with Entitlements
echo "🔏 Signing App with Entitlements..."
codesign --force --deep --entitlements SharedCalendarApp.entitlements --sign - "$APP_BUNDLE"

# 7. Run the App using 'open' (NEW STEP)
# Using 'open' asks the Finder to launch it, which is required for permissions prompts to appear correctly.
echo "🚀 Launching App..."
open "$APP_BUNDLE"