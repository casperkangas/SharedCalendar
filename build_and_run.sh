#!/bin/bash

# --- DEFAULTS ---
BUILD_MODE="debug"  # or "release"
RUN_APP=true
CLEAN_BUILD=false

# --- PARSE ARGUMENTS ---
for arg in "$@"
do
    case $arg in
        --release)
            BUILD_MODE="release"
            ;;
        --clean)
            CLEAN_BUILD=true
            ;;
        --no-run)
            RUN_APP=false
            ;;
        --help)
            echo "Usage: ./build_and_run.sh [OPTIONS]"
            echo "Options:"
            echo "  --release   Build optimized version (hides Debug UI)"
            echo "  --clean     Delete cached build files before building"
            echo "  --no-run    Build only, do not launch the app"
            exit 0
            ;;
    esac
done

# --- 1. CLEANUP (If requested) ---
APP_NAME="SharedCalendarApp"
APP_BUNDLE="$APP_NAME.app"

if [ "$CLEAN_BUILD" = true ]; then
    echo "🧹 Cleaning build artifacts..."
    rm -rf .build
    rm -rf "$APP_BUNDLE"
    # We resolve packages again to ensure dependencies are fresh
    echo "📦 Resolving dependencies..."
    swift package resolve
fi

# --- 2. BUILD ---
echo "🔨 Building Project ($BUILD_MODE mode)..."
swift build -c $BUILD_MODE

# Check if build succeeded
if [ $? -ne 0 ]; then
    echo "❌ Build failed."
    exit 1
fi

# --- 3. CREATE BUNDLE ---
BUILD_DIR=".build/$BUILD_MODE"

echo "📂 Creating App Bundle..."
# Remove old bundle if it exists to prevent stale files
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
if [ -f "Info.plist" ]; then
    cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
else
    echo "⚠️ Warning: Info.plist not found!"
fi

# Copy Firebase Config
if [ -f "GoogleService-Info.plist" ]; then
    echo "📄 Copying Firebase Config..."
    cp GoogleService-Info.plist "$APP_BUNDLE/Contents/Resources/GoogleService-Info.plist"
else
    echo "❌ Error: GoogleService-Info.plist missing! App will crash."
    exit 1
fi

# --- 4. SIGNING ---
echo "🔏 Signing App..."
codesign --force --deep --sign - "$APP_BUNDLE"

# --- 5. LAUNCH ---
if [ "$RUN_APP" = true ]; then
    echo "🚀 Launching App..."
    open "$APP_BUNDLE"
else
    echo "✅ Build Complete. App is at: $APP_BUNDLE"
fi