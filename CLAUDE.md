# LidKeeper

選單列 app，開關 macOS 的 `SleepDisabled` 旗標（闔蓋不睡）。只有 Kyle 自己用，兩台 Mac 各自編譯。

## 刻意保持小

這個專案的價值就是小。**加功能之前先問是不是真的需要**，預設答案是不要：

- 不要加閒置逾時、排程、快捷鍵、偏好設定視窗、通知。要那些的話 Amphetamine 已經有了。
- 不要為了支援 Intel Mac 或舊系統加相容層。兩台都是 Apple Silicon + 最新 macOS。
- 不要加 app icon、about 視窗、更新檢查。它沒有 Dock 圖示（`LSUIElement`），使用者只會看到選單列那顆。

## 架構

一個 SwiftPM executable，包成 `.app` bundle。兩個檔案：

- `Sources/LidKeeper/LidKeeperApp.swift`：`MenuBarExtra` 的選單內容，純 UI。
- `Sources/LidKeeper/SleepState.swift`：讀寫系統狀態，所有邏輯都在這。

`build.sh` 編譯後手動組 bundle（執行檔 + `Info.plist` + `AppIcon.icns` + 提權腳本 + ad-hoc 簽名）。沒有 Xcode 專案檔，不要加。

圖示由 `Tools/make-icon.sh` 產生（`Tools/make-icon.swift` 用 AppKit 畫，SF Symbol `cup.and.saucer.fill` 配深靛藍漸層底），產物 `AppIcon.icns` 有 commit 進 repo，所以另一台電腦 build 不用重畫。只有要改圖才需要跑那支。改完圖示 Finder 可能還顯示舊的，`touch LidKeeper.app` 或跑 `lsregister -f` 清 LaunchServices 快取。

## 讀寫是兩條不同的路

這是這個 app 唯一需要理解的事情：

- **讀狀態**不需要權限，從 IORegistry 讀 `IOPMrootDomain` 的 `SleepDisabled`（`ioreg -r -c IOPMrootDomain -d 1`），值是 `Yes` / `No` 的字串。不要改成 parse `pmset -g`，那個輸出在預設狀態下根本不會列出 `SleepDisabled` 這行。
- **寫狀態**只能透過 `sudo pmset -a disablesleep 0|1`，需要 root。app 先試 `sudo -n`（免密碼路徑），失敗就用 `osascript ... with administrator privileges` 彈系統密碼框，在那一次裡把 sudoers 裝好並順手切換狀態。所以使用者永遠不需要開終端機，密碼只會被問一次。

提權時執行的是 **bundle 裡的** `Contents/Resources/install-sudoers.sh`，不是暫存目錄的檔案。這是刻意的：以 root 執行一個別人可以替換的路徑等於開後門。要改這段就維持這個性質。

sudoers 那條**只放行 `disablesleep 0` 和 `1` 兩條完整指令**，不要為了省事改成萬用字元，那等於把整個 `pmset` 開成免密碼。

狀態每 5 秒重讀一次，因為使用者可能在終端機直接改。

## 結束前一定要問

`SleepDisabled` 是寫在系統上的，app 結束不會還原。所以在「闔蓋不會睡」的狀態下按結束，會先跳一個對話框問要留下哪個狀態（保持清醒 / 恢復正常睡眠 / 取消）；正常睡眠的狀態下沒有東西會殘留，直接結束不問。

**不要把這個對話框拿掉去換取「乾脆一點」**。沒有它的話，使用者關掉 app 之後電腦會一直維持不睡，而選單列上已經沒有任何東西告訴他這件事，也沒有開關可以改。

## 測試

沒有自動化測試。改完就 `./build.sh` 然後 `open LidKeeper.app`，肉眼看選單列圖示對不對、按下去有沒有切換。

注意：從 Claude Code 的 shell 無法驗證選單列圖示（螢幕錄製和輔助使用權限都拿不到），**UI 有沒有正常出現只能請 Kyle 看一眼**，不要自己宣稱驗過了。

## 名詞

- **clamshell 模式**：接了外接螢幕 + 電源時，闔蓋不睡。這是 macOS 本來就有的行為，跟這個 app 無關。
- **`SleepDisabled`**：這個 app 開關的旗標。跟系統設定「電池」裡那個「避免在顯示器關閉時自動進入睡眠」不是同一件事，那個是 `pmset sleep 0`，只管閒置。
