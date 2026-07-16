#!/bin/zsh
set -e

# 自动安装 Homebrew（如果不存在）
if ! command -v brew >/dev/null 2>&1; then
  echo "检测到 Homebrew 未安装，开始安装..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # 配置 PATH（Intel 和 Apple Silicon 兼容）
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# 确保 brew 可用
command -v brew >/dev/null || { echo "Homebrew 安装失败"; exit 1; }

brew list ffmpeg >/dev/null 2>&1 || brew install ffmpeg
brew list python >/dev/null 2>&1 || brew install python
python3 -m pip install --user pillow

chmod +x "$(dirname "$0")/vthumb-mac.sh"

dir="$(cd "$(dirname "$0")" && pwd)"
touch "$HOME/.zprofile"
grep -Fqx "export PATH=\"$dir:\$PATH\"" "$HOME/.zprofile" || echo "export PATH=\"$dir:\$PATH\"" >> "$HOME/.zprofile"

echo "macOS 环境已安装，请重新打开终端。"
