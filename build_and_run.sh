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
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 4. Copy the compiled binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# 5. Copy Info.plist
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

# 5.5 Copy Firebase Config (NEW STEP)
echo "📄 Copying Firebase Config..."
cp GoogleService-Info.plist "$APP_BUNDLE/Contents/Resources/GoogleService-Info.plist"

# 6. Ad-hoc Signing
echo "🔏 Signing App..."
codesign --force --deep --sign - "$APP_BUNDLE"

# 7. Run
echo "🚀 Launching App..."
open "$APP_BUNDLE"