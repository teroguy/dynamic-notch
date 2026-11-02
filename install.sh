#!/usr/bin/env bash
set -e

# Automatically find Xcode if xcode-select points to CommandLineTools
if ! xcodebuild -version &>/dev/null; then
    if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    else
        echo "❌ Ошибка: Xcode.app не найден в /Applications/Xcode.app."
        echo "Установите Xcode или настройте xcode-select:"
        echo "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        exit 1
    fi
fi

echo "🔨 Сборка Dynamic Notch..."
xcodebuild -scheme boringNotch -configuration Debug -derivedDataPath .build build -quiet

APP_SRC=$(find .build/Build/Products -name "Boring Notch.app" -type d | head -n 1)

if [ -z "$APP_SRC" ]; then
    echo "❌ Ошибка: не удалось найти скомпилированное приложение."
    exit 1
fi

echo "📦 Установка в /Applications/Boring Notch.app..."
osascript -e 'tell application "Boring Notch" to quit' 2>/dev/null || true
sleep 1

ditto "$APP_SRC" "/Applications/Boring Notch.app"

# Clean build artifacts to avoid Spotlight duplicates
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$APP_SRC" 2>/dev/null || true
rm -rf .build

echo "🚀 Запуск Dynamic Notch..."
open "/Applications/Boring Notch.app"

echo "✅ Готово! Dynamic Notch успешно собран и запущен."
