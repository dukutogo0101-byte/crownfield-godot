#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$TASK_ROOT/../runtime/Godot_v4.5.2-stable_linux.x86_64}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$TASK_ROOT/../runtime/android_sdk}"
export CROWNFIELD_DEBUG_KEYSTORE="${CROWNFIELD_DEBUG_KEYSTORE:-$HOME/.local/share/crownfield/debug.keystore}"
mkdir -p "$TASK_ROOT/builds" "$(dirname "$CROWNFIELD_DEBUG_KEYSTORE")"
if [[ ! -f "$CROWNFIELD_DEBUG_KEYSTORE" ]]; then
    "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$CROWNFIELD_DEBUG_KEYSTORE" -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname 'CN=Android Debug,O=Android,C=US'
fi
"$GODOT_BIN" --headless --editor --path "$TASK_ROOT" --quit 2>&1 | tee "$TASK_ROOT/builds/import.log"
"$GODOT_BIN" --headless --editor --path "$TASK_ROOT" --script res://tools/configure_android.gd 2>&1 | tee "$TASK_ROOT/builds/android_configuration.log"
python3 "$TASK_ROOT/tools/build_manifest.py" start
"$GODOT_BIN" --headless --path "$TASK_ROOT" --export-release 'Linux Desktop' "$TASK_ROOT/builds/Crownfield.x86_64" 2>&1 | tee "$TASK_ROOT/builds/linux_export.log"
"$GODOT_BIN" --headless --path "$TASK_ROOT" --export-release 'Windows Desktop' "$TASK_ROOT/builds/Crownfield.exe" 2>&1 | tee "$TASK_ROOT/builds/windows_export.log"
"$GODOT_BIN" --headless --path "$TASK_ROOT" --export-debug Android "$TASK_ROOT/builds/Crownfield-debug.apk" 2>&1 | tee "$TASK_ROOT/builds/android_export.log"
python3 "$TASK_ROOT/tools/build_manifest.py" finish
"$TASK_ROOT/builds/Crownfield.x86_64" --headless --quit-after 30 2>&1 | tee "$TASK_ROOT/builds/linux_binary_boot.log"
if rg -q 'SCRIPT ERROR:|Parse Error:|Failed loading resource|ERROR:' "$TASK_ROOT/builds/linux_binary_boot.log"; then
    printf '%s\n' 'Linux binary startup reported an error; build verification failed.' >&2
    exit 1
fi
"$ANDROID_SDK_ROOT/build-tools/35.0.0/apksigner" verify --verbose "$TASK_ROOT/builds/Crownfield-debug.apk" > "$TASK_ROOT/builds/android_signature.log"
"$ANDROID_SDK_ROOT/build-tools/35.0.0/aapt" dump badging "$TASK_ROOT/builds/Crownfield-debug.apk" > "$TASK_ROOT/builds/android_manifest.log"
"$ANDROID_SDK_ROOT/build-tools/35.0.0/aapt" dump permissions "$TASK_ROOT/builds/Crownfield-debug.apk" > "$TASK_ROOT/builds/android_permissions.log"
"$ANDROID_SDK_ROOT/platform-tools/adb" devices > "$TASK_ROOT/builds/android_devices.log"
python3 "$TASK_ROOT/tools/build_manifest.py" verify
