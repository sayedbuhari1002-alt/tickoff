#!/usr/bin/env bash
# Generates the Android Gradle scaffold with the Flutter SDK installed on the
# build machine (so Gradle/AGP/Kotlin versions always match that SDK), then
# applies the small customisations this app needs.
# Safe to run repeatedly: it only generates android/ when it is missing.
set -euo pipefail

PROJECT_NAME="tickoff_replacement"
ORG="dev.tickoffreplacement"
APP_LABEL="TickOff"

if [ ! -d "android/app" ]; then
  echo "Generating Android scaffold with the installed Flutter SDK..."
  SCAFFOLD_DIR="$(mktemp -d)"
  flutter create --platforms=android \
    --project-name "$PROJECT_NAME" \
    --org "$ORG" \
    "$SCAFFOLD_DIR/$PROJECT_NAME"
  cp -R "$SCAFFOLD_DIR/$PROJECT_NAME/android" ./android
  rm -f android/local.properties
else
  echo "android/ already exists - leaving it untouched."
fi

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  sed -i "s/android:label=\"[^\"]*\"/android:label=\"$APP_LABEL\"/" "$MANIFEST"
  echo "App label set to $APP_LABEL"
else
  echo "ERROR: $MANIFEST not found" >&2
  exit 1
fi

# Permissions required by local reminders, photo capture, and voice notes.
if [ -f "$MANIFEST" ]; then
  grep -q 'android.permission.POST_NOTIFICATIONS' "$MANIFEST" || sed -i '/<application/i\    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <uses-permission android:name="android.permission.RECORD_AUDIO" />\n    <uses-permission android:name="android.permission.CAMERA" />\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />\n    <uses-permission android:name="android.permission.VIBRATE" />' "$MANIFEST"
fi

# Audio recording plugins require Android 23 or newer.
APP_GRADLE="android/app/build.gradle.kts"
if [ -f "$APP_GRADLE" ]; then
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' "$APP_GRADLE"
fi
if [ -f "$APP_GRADLE" ]; then
  if ! grep -q 'isCoreLibraryDesugaringEnabled' "$APP_GRADLE"; then
    sed -i '/compileOptions {/a\        isCoreLibraryDesugaringEnabled = true' "$APP_GRADLE"
  fi
  if ! grep -q 'desugar_jdk_libs' "$APP_GRADLE"; then
    sed -i '/dependencies {/a\    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' "$APP_GRADLE"
  fi
fi
