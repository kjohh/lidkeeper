#!/bin/bash
# 讓 LidKeeper 能免密碼切換 disablesleep。每台電腦跑一次。
#
# 用法（兩種都可以，通常由 app 自己呼叫，不用手動跑）：
#   sudo ./Scripts/install-sudoers.sh              終端機手動裝
#   install-sudoers.sh <使用者> [0|1]              app 提權後呼叫，順便設定狀態
set -e

if [ "$EUID" -ne 0 ]; then
    echo "要用 sudo 跑：sudo ./Scripts/install-sudoers.sh"
    exit 1
fi

# app 提權呼叫時沒有 SUDO_USER（whoami 會是 root），所以第一個參數優先
USER_NAME="${1:-${SUDO_USER:-$(whoami)}}"
TARGET="$2"
FILE="/etc/sudoers.d/lidkeeper"

# 只放行這兩條指令，其他 pmset 參數一律還是要密碼
cat > "$FILE" <<EOF
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1
EOF

chmod 440 "$FILE"
visudo -c -f "$FILE" >/dev/null

# 有帶第二個參數就順手把狀態切過去，省得使用者再按一次
if [ -n "$TARGET" ]; then
    /usr/bin/pmset -a disablesleep "$TARGET"
fi

echo "好了，$USER_NAME 現在可以免密碼切換 disablesleep。"
