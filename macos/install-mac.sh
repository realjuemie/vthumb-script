#!/bin/zsh
set -e
command -v brew >/dev/null || { echo '请先安装 Homebrew: https://brew.sh'; exit 1; }
brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg
brew list python >/dev/null 2>&1 || brew install python
python3 -m pip install --user pillow
chmod +x "$(dirname "$0")/vthumb-mac.sh"
dir="$(cd "$(dirname "$0")" && pwd)"; touch "$HOME/.zprofile"
grep -Fqx "export PATH=\"$dir:\$PATH\"" "$HOME/.zprofile" || echo "export PATH=\"$dir:\$PATH\"" >> "$HOME/.zprofile"
echo 'macOS 环境已安装，请重新打开终端。'
