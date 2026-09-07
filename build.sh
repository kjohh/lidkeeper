#!/bin/bash
# 編譯出 LidKeeper.app，就地放在專案根目錄。
set -e
cd "$(dirname "$0")"

swift build -c release

APP="LidKeeper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/LidKeeper "$APP/Contents/MacOS/LidKeeper"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# 提權安裝腳本要放在 bundle 裡，這樣以 root 執行的東西不會是別人能替換掉的暫存檔
cp Scripts/install-sudoers.sh "$APP/Contents/Resources/install-sudoers.sh"
chmod +x "$APP/Contents/Resources/install-sudoers.sh"

# 闔蓋要播的聲音。還沒放就跳過，app 那邊會退回系統語音
if compgen -G "Resources/lid-closed.*" > /dev/null; then
  cp Resources/lid-closed.* "$APP/Contents/Resources/"
fi

# ad-hoc 簽名。本機編出來的 app 沒有 quarantine 標記，這樣就夠了。
codesign --force --sign - "$APP"

echo "好了：$(pwd)/$APP"
