#!/usr/bin/env bash
set -e

echo "🔨 Сборка Dynamic Notch..."
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

xcodebuild -scheme boringNotch -configuration Debug -derivedDataPath .build build -quiet

APP_PATH=$(find .build/Build/Products -name "Boring Notch.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Ошибка: приложение не найдено в .build"
    exit 1
fi

echo "📦 Создание установочного файла DynamicNotch.dmg..."
DMG_STAGE="/tmp/dynamic_notch_dmg_stage"
rm -rf "$DMG_STAGE" DynamicNotch.dmg
mkdir -p "$DMG_STAGE"

ditto "$APP_PATH" "$DMG_STAGE/Boring Notch.app"
ln -s /Applications "$DMG_STAGE/Applications"

hdiutil create -volname "Dynamic Notch" -srcfolder "$DMG_STAGE" -ov -format UDZO "DynamicNotch.dmg"
rm -rf "$DMG_STAGE" .build

echo "✅ Установочный файл готов: DynamicNotch.dmg"
