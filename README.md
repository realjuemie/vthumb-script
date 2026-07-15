# vthumb-script

> [English](README_en.md) | [中文文档](README.md)

视频缩略图一键生成脚本 —— 兼容 **Windows** 和 **macOS**。

在文件夹中一键运行，自动为该文件夹下的所有视频生成 PotPlayer 风格的联系表缩略图（含视频信息 + 时间戳拼图）。

## 平台支持

| 平台 | 目录 | 入口脚本 |
|------|------|----------|
| Windows | `windows/` | `vthumb.cmd`（CMD）/ `vthumb.ps1`（PowerShell） |
| macOS | `macos/` | `vthumb-mac.sh`（终端） |

## 功能

- 横版视频 → 16:9 缩略图网格
- 竖版视频 → 9:16 竖版缩略图（自动检测方向，不会强制填充黑边）
- 顶部信息栏：文件名 / 大小 / 分辨率 / 编码 / 时长
- 每帧底部居中时间戳
- 输出 `<原文件名>.png` 在原视频同目录

## Windows 安装

进入 `windows` 文件夹，双击 `install.cmd`，或在 PowerShell 中：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\install-windows.ps1
```

脚本会通过 `winget` 安装 FFmpeg（如果未安装），并把工具目录加入 PATH。

## Windows 使用

在包含视频的文件夹中打开 CMD：

```cmd
vthumb
```

```cmd
vthumb "D:\Videos" -Count 20 -Cols 5 -Width 1280 -Recurse -Force
```

### 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-Path` | `.` | 视频文件夹路径 |
| `-Count` | `16` | 每视频抽取帧数 |
| `-Cols` | `4` | 网格列数 |
| `-Width` | `1920` | 输出 PNG 宽度 |
| `-Recurse` | 关闭 | 递归子文件夹 |
| `-Force` | 关闭 | 覆盖已有输出 |

## macOS 安装

```bash
chmod +x macos/install-mac.sh macos/vthumb-mac.sh
./macos/install-mac.sh
```

需要 FFmpeg、Python 3 和 Pillow。

## macOS 使用

```bash
./macos/vthumb-mac.sh
./macos/vthumb-mac.sh -Path "/Users/me/Videos" -Count 20 -Cols 5 -Width 1280 -Recurse
```

### 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-Path` | `.` | 视频文件夹路径 |
| `-Count` | `16` | 每视频抽取帧数 |
| `-Cols` | `4` | 网格列数 |
| `-Width` | `1920` | 输出 PNG 宽度 |
| `-Recurse` | 关闭 | 递归子文件夹 |
| `-Force` | 关闭 | 覆盖已有输出 |

## 支持的视频格式

`3g2` `3gp` `asf` `avi` `divx` `flv` `m2ts` `m4v` `mkv` `mov` `mp4`
`mpeg` `mpg` `mts` `ogm` `ogv` `rm` `rmvb` `ts` `vob` `webm` `wmv`

## 输出文件

输出 PNG 保存在原视频同目录，文件名格式为：

```
原视频文件名.扩展名.png
```

例如 `movie.mp4` → `movie.mp4.png`。已有 PNG 默认跳过，使用 `-Force` 覆盖。

## 许可

MIT