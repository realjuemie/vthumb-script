# vthumb-script

> [中文文档](README.md) | [English](README_en.md)

One-click video thumbnail contact-sheet generator — **Windows** and **macOS**.

Run a single command in any video folder and get PotPlayer-style thumbnail grids
with metadata headers and timestamp labels for every video.

## Platform support

| Platform | Folder | Entry script |
|----------|--------|-------------|
| Windows | `windows/` | `vthumb.cmd` (CMD) / `vthumb.ps1` (PowerShell) |
| macOS | `macos/` | `vthumb-mac.sh` (Terminal) |

## Features

- Landscape videos → 16:9 thumbnail grid
- Portrait videos → 9:16 grid (auto-detected, no forced letterbox)
- Header strip: filename / size / resolution / codec / duration
- Timestamp centered at the bottom of each frame
- Output `<source>.png` alongside the video file

## Windows install

Open the `windows` folder and double-click `install.cmd`, or in PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\install-windows.ps1
```

The script installs FFmpeg via `winget` (if missing) and adds the tool to PATH.

## Windows usage

Open CMD in a video folder:

```cmd
vthumb
```

```cmd
vthumb "D:\Videos" -Count 20 -Cols 5 -Width 1280 -Recurse -Force
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Path` | `.` | Video folder path |
| `-Count` | `16` | Frames per video |
| `-Cols` | `4` | Grid columns |
| `-Width` | `1920` | Output PNG width (px) |
| `-Recurse` | off | Process subfolders |
| `-Force` | off | Overwrite existing output |

## macOS install

```bash
chmod +x macos/install-mac.sh macos/vthumb-mac.sh
./macos/install-mac.sh
```

Requires FFmpeg, Python 3, and Pillow.

## macOS usage

```bash
./macos/vthumb-mac.sh
./macos/vthumb-mac.sh -Path "/Users/me/Videos" -Count 20 -Cols 5 -Width 1280 -Recurse
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Path` | `.` | Video folder path |
| `-Count` | `16` | Frames per video |
| `-Cols` | `4` | Grid columns |
| `-Width` | `1920` | Output PNG width (px) |
| `-Recurse` | off | Process subfolders |
| `-Force` | off | Overwrite existing output |

## Supported formats

`3g2` `3gp` `asf` `avi` `divx` `flv` `m2ts` `m4v` `mkv` `mov` `mp4`
`mpeg` `mpg` `mts` `ogm` `ogv` `rm` `rmvb` `ts` `vob` `webm` `wmv`

## Output

Output PNGs are written alongside source videos:

```
source.ext.png
```

e.g. `movie.mp4` → `movie.mp4.png`. Existing files are skipped unless `-Force` is used.

## License

MIT