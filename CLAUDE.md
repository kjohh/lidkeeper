# LidKeeper

選單列 app，開關 macOS 的 `SleepDisabled` 旗標（闔蓋不睡）。自用工具，兩台 Mac 各自編譯。

## 刻意保持小

這個專案的價值就是小。**加功能之前先問是不是真的需要**，預設答案是不要：

- 不要加閒置逾時、排程、快捷鍵、偏好設定視窗、通知。要那些的話 Amphetamine 已經有了。
- 不要為了支援 Intel Mac 或舊系統加相容層。兩台都是 Apple Silicon + 最新 macOS。
- 不要加 app icon、about 視窗、更新檢查。它沒有 Dock 圖示（`LSUIElement`），使用者只會看到選單列那顆。

## 架構

一個 SwiftPM executable，包成 `.app` bundle：

- `Sources/LidKeeper/LidKeeperApp.swift`：`MenuBarExtra` 的選單內容，純 UI。
- `Sources/LidKeeper/SleepState.swift`：讀寫系統狀態、看著蓋子開闔，所有邏輯都在這。
- `Sources/LidKeeper/LidVoice.swift`：闔蓋時出聲，只管挑檔案跟播放。
- `Sources/LidKeeper/LaunchHint.swift`：啟動後從選單列滑出來的提示氣泡。

`build.sh` 編譯後手動組 bundle（執行檔 + `Info.plist` + `AppIcon.icns` + 提權腳本 + ad-hoc 簽名）。沒有 Xcode 專案檔，不要加。

圖示由 `Tools/make-icon.sh` 產生（`Tools/make-icon.swift` 用 AppKit 畫，SF Symbol `cup.and.saucer.fill` 配深靛藍漸層底），產物 `AppIcon.icns` 有 commit 進 repo，所以另一台電腦 build 不用重畫。只有要改圖才需要跑那支。改完圖示 Finder 可能還顯示舊的，`touch LidKeeper.app` 或跑 `lsregister -f` 清 LaunchServices 快取。

## 讀寫是兩條不同的路

這是這個 app 唯一需要理解的事情：

- **讀狀態**不需要權限，從 IORegistry 讀 `IOPMrootDomain` 的 `SleepDisabled`（`ioreg -r -c IOPMrootDomain -d 1`），值是 `Yes` / `No` 的字串。不要改成 parse `pmset -g`，那個輸出在預設狀態下根本不會列出 `SleepDisabled` 這行。
- **寫狀態**只能透過 `sudo pmset -a disablesleep 0|1`，需要 root。app 先試 `sudo -n`（免密碼路徑），失敗就用 `osascript ... with administrator privileges` 彈系統密碼框，在那一次裡把 sudoers 裝好並順手切換狀態。所以使用者永遠不需要開終端機，密碼只會被問一次。

提權時執行的是 **bundle 裡的** `Contents/Resources/install-sudoers.sh`，不是暫存目錄的檔案。這是刻意的：以 root 執行一個別人可以替換的路徑等於開後門。要改這段就維持這個性質。

sudoers 那條**只放行 `disablesleep 0` 和 `1` 兩條完整指令**，不要為了省事改成萬用字元，那等於把整個 `pmset` 開成免密碼。

狀態每 5 秒重讀一次，因為使用者可能在終端機直接改。

## 闔蓋時說話

選單上的「闔蓋時說話」打開之後，闔蓋會播一段聲音說它不會睡。預設是開的，開關記在 UserDefaults 的 `announceOnLidClose`。

只有在「闔蓋不會睡」的狀態下才出聲。本來就要睡的話，講到一半也會被系統切掉，不如不要講。

**蓋子的狀態不要另外查。** `ioreg -r -c IOPMrootDomain -d 1`（讀 `SleepDisabled` 的那支）輸出裡就有 `AppleClamshellState`，同一份輸出裡撈就好。注意隔壁還有一個 `AppleClamshellCausesSleep`，比對的時候要連引號一起帶，不然會抓錯行。

**偵測闔蓋走 IOKit 事件，不要靠輪詢。** 5 秒的輪詢間隔拿來偵測闔蓋太慢（闔上五秒後才出聲，人都走了），而把間隔縮短會讓一個長時間闔蓋放著的 app 一直在燒電。所以是對 `IOPMrootDomain` 註冊 general interest 通知，事件進來就重讀一次。這裡刻意不去比對 `kIOPMMessageClamshellStateChange` 那類訊息代號，因為它們在 Swift 裡沒有公開常數、值要自己算；收到任何電源事件就重讀，行為一樣而且不會算錯。5 秒的輪詢仍然留著當保底。

出聲會延遲 1.2 秒。蓋上的瞬間音訊輸出還在切換，太早講會被吃掉開頭。這段期間如果蓋子又被打開，就取消不講。

### 換聲音

音檔放 `Resources/lid-closed.<副檔名>`，`build.sh` 會把它複製進 bundle。m4a、mp3、wav、aiff、caf 都吃，程式會自己找。

**沒放音檔的話會退回系統語音講一句英文。** 那個聲音很機械，只是為了讓功能在還沒挑好聲音的時候也是活的，不是最終樣貌。放了檔案就會自動改用檔案，程式不用動。

## 面板長什麼樣

選單列點開的是自訂面板（`MenuBarExtra` 的 window 樣式），不是系統選單。設計定案在這裡，改畫面之前先看過：

<https://claude.ai/code/artifact/ebe5e944-bcf5-489f-9f16-eaa0bab9c975>

那頁上有六個提案，採用的是第二排最右邊的**霧藍**那版。前面幾案和第一版的四案都留著當比較，不是還在考慮的選項。

畫面上有兩個各自獨立的狀態，不要把它們綁在一起：

- **精靈有沒有生命**：跟著「闔蓋保持清醒」。開著是霧藍色、會呼吸、眼睛跟著游標；關掉就只剩一顆閉著眼的灰球。
- **筆電開著還是闔著**：點插畫切換，純粹好玩，跟任何設定都無關。預設是打開的。

闔起來的時候上蓋**故意蓋不到底**，露出的那截機身前緣本身就是光，眼睛在那片光裡。不要為了整齊把它蓋滿，蓋滿就沒有光可以漏出來，而另外疊一塊發光的東西上去只會變成一塊貼紙。同理，那片光不能有硬邊。

## 打開時要有反應

`LSUIElement` 的 app 在 Finder 點兩下之後畫面上什麼都不會發生，使用者不知道它去了哪裡。所以啟動後會從選單列圖示滑出一個 popover 說明它在那裡，6 秒後自己收掉，也可以按「知道了」關掉。

錨點是從 `NSApp.windows` 裡找型別名稱含 `StatusBar` 的 window 拿到的，因為 SwiftUI 的 `MenuBarExtra` 沒有公開 `NSStatusItem`。這段依賴 SwiftUI 的內部命名，哪天 Apple 改了就會找不到錨點：那時的行為是**提示安靜地不出現**，app 其他功能完全不受影響。這是刻意選的失敗方式，不要改成硬跳一個置中的視窗。

status item 是非同步建立的，所以找不到時會每 0.3 秒重試，最多 10 次。

這段有兩個坑，改動的時候不要踩回去：

- **錨點剛出現時 `bounds.height` 是 0**，那個狀態下 `popover.show` 會靜靜地失敗（`isShown` 留在 false），所以重試條件是「找到 window **而且** 高度大於 0」，不能只判斷找不找得到。
- **`popover.contentSize` 一定要自己給**。`NSHostingController` 在這裡算不出 intrinsic size，`preferredContentSize` 會是 0 乘 0，popover 開了也是看不見的。

app 已經在跑的時候再去 Finder 點兩下，macOS 只發 reopen 事件、不會重新啟動，`applicationDidFinishLaunching` 不會再跑。所以 `applicationShouldHandleReopen` 也要叫出提示，文字換成「已經開著了」。少了這條的話使用者會覺得點兩下沒反應。

## 結束前一定要問

`SleepDisabled` 是寫在系統上的，app 結束不會還原。所以在「闔蓋不會睡」的狀態下按結束，會先跳一個對話框問要留下哪個狀態（保持清醒 / 恢復正常睡眠 / 取消）；正常睡眠的狀態下沒有東西會殘留，直接結束不問。

**不要把這個對話框拿掉去換取「乾脆一點」**。沒有它的話，使用者關掉 app 之後電腦會一直維持不睡，而選單列上已經沒有任何東西告訴他這件事，也沒有開關可以改。

## 測試

沒有自動化測試。改完就 `./build.sh` 然後 `open LidKeeper.app`，肉眼看選單列圖示對不對、按下去有沒有切換。

注意：從 Claude Code 的 shell 無法驗證選單列圖示（螢幕錄製和輔助使用權限都拿不到），**UI 有沒有正常出現只能請人看一眼**，不要自己宣稱驗過了。

## 名詞

- **clamshell 模式**：接了外接螢幕 + 電源時，闔蓋不睡。這是 macOS 本來就有的行為，跟這個 app 無關。
- **`SleepDisabled`**：這個 app 開關的旗標。跟系統設定「電池」裡那個「避免在顯示器關閉時自動進入睡眠」不是同一件事，那個是 `pmset sleep 0`，只管閒置。
