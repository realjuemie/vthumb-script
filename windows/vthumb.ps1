param(
    [string]$Path = ".",
    [int]$Count = 16,
    [int]$Cols = 4,
    [int]$Width = 1920,
    [switch]$Recurse,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Find-Executable($name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "Cannot find $name. Please install FFmpeg and add its bin folder to PATH."
    }
    return $cmd.Source
}

function Format-Time([double]$seconds) {
    if ($seconds -lt 0 -or [double]::IsNaN($seconds)) { $seconds = 0 }
    $ts = [TimeSpan]::FromSeconds([Math]::Floor($seconds))
    if ($ts.TotalHours -ge 1) {
        return "{0:00}:{1:00}:{2:00}" -f [Math]::Floor($ts.TotalHours), $ts.Minutes, $ts.Seconds
    }
    return "{0:00}:{1:00}:{2:00}" -f $ts.Hours, $ts.Minutes, $ts.Seconds
}

function Format-Size([long]$bytes) {
    $mb = $bytes / 1MB
    return "{0:N2}MB({1:N0} bytes)" -f $mb, $bytes
}

function Get-SampleTime([double]$duration, [int]$index, [int]$count) {
    $defaultTime = ($duration * $index) / ($count + 1)
    if ($index -ne 1) { return $defaultTime }

    # Move the first thumbnail earlier on long videos, but avoid the very first
    # frames where black leaders and fades are common.
    $earlyTime = [Math]::Max($duration * 0.02, [Math]::Min(3.0, $duration * 0.1))
    return [Math]::Min($defaultTime, $earlyTime)
}

function Invoke-Process($exe, [string[]]$arguments) {
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$([IO.Path]::GetFileName($exe)) failed with exit code $LASTEXITCODE."
    }
}

function Text-FromCodePoints([int[]]$codePoints) {
    return -join ($codePoints | ForEach-Object { [char]$_ })
}

function Get-MediaInfo($ffprobe, [string]$file) {
    $json = & $ffprobe -v error -print_format json -show_format -show_streams -- $file
    if (-not $json) { throw "ffprobe returned no data." }
    $info = $json | ConvertFrom-Json
    $video = @($info.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1)[0]
    $audio = @($info.streams | Where-Object { $_.codec_type -eq "audio" } | Select-Object -First 1)[0]
    if (-not $video) { throw "No video stream found." }

    # FFmpeg applies display rotation while extracting frames.  Use the same
    # orientation for the contact-sheet layout rather than the encoded frame
    # dimensions, which may still be landscape for a portrait recording.
    $rotation = 0
    if ($video.side_data_list) {
        $rotationSideData = @($video.side_data_list | Where-Object { $_.rotation -ne $null } | Select-Object -First 1)[0]
        if ($rotationSideData) { $rotation = [int]$rotationSideData.rotation }
    }
    if ($rotation -eq 0 -and $video.tags -and $video.tags.rotate) {
        $rotation = [int]$video.tags.rotate
    }
    $rotation = (($rotation % 360) + 360) % 360
    $displayWidth = [int]$video.width
    $displayHeight = [int]$video.height
    if ($rotation -eq 90 -or $rotation -eq 270) {
        $displayWidth = [int]$video.height
        $displayHeight = [int]$video.width
    }

    $duration = 0.0
    if ($info.format.duration) { $duration = [double]$info.format.duration }
    elseif ($video.duration) { $duration = [double]$video.duration }

    $fps = ""
    if ($video.avg_frame_rate -and $video.avg_frame_rate -match "^(\d+)/(\d+)$" -and [int]$Matches[2] -ne 0) {
        $fpsValue = [double]$Matches[1] / [double]$Matches[2]
        $fps = "{0:0.##}" -f $fpsValue
    }

    return [pscustomobject]@{
        Duration = $duration
        Width = $displayWidth
        Height = $displayHeight
        Fps = $fps
        VideoCodec = if ($video.codec_name) { $video.codec_name.ToUpperInvariant() } else { "UNKNOWN" }
        AudioCodec = if ($audio -and $audio.codec_name) { $audio.codec_name.ToUpperInvariant() } else { "NONE" }
    }
}

function Draw-OutlinedText($graphics, [string]$text, $font, $brush, [float]$x, [float]$y, [float]$outlineWidth = 3) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $format = [System.Drawing.StringFormat]::GenericTypographic
    $format.FormatFlags = $format.FormatFlags -bor [System.Drawing.StringFormatFlags]::NoClip
    $emSize = $font.SizeInPoints * $graphics.DpiY / 72
    $path.AddString($text, $font.FontFamily, [int]$font.Style, $emSize, [System.Drawing.PointF]::new($x, $y), $format)

    $outline = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(245, 0, 0, 0), $outlineWidth)
    $outline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $graphics.DrawPath($outline, $path)
    $graphics.FillPath($brush, $path)

    $outline.Dispose()
    $path.Dispose()
}

function New-RoundedRectanglePath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Compose-ContactSheet($videoFile, $outputFile, $frames, $times, $meta, $sheetWidth, $cols) {
    Add-Type -AssemblyName System.Drawing

    $margin = 10
    $gap = 8
    $headerFontSize = [Math]::Max(11, [Math]::Round($sheetWidth / 85))
    # Keep timestamps compact so they do not dominate each thumbnail.
    $stampFontSize = [Math]::Max(10, [Math]::Round($sheetWidth / 90))
    $lineHeight = [Math]::Ceiling($headerFontSize * 1.35)
    # A long filename is split into readable lines before calculating the
    # header height, so it never runs into the thumbnail grid.
    $maxHeaderChars = [int][Math]::Max(20, [Math]::Floor($sheetWidth / ($headerFontSize * 1.1)))
    $tileW = [int][Math]::Floor(($sheetWidth - ($margin * 2) - ($gap * ($cols - 1))) / $cols)
    # Preserve the video's display aspect ratio.  This remains 16:9 for
    # landscape videos and makes portrait videos use portrait tiles.
    $aspectRatio = if ($meta.Width -gt 0 -and $meta.Height -gt 0) { [double]$meta.Width / [double]$meta.Height } else { 16.0 / 9.0 }
    $tileH = [int][Math]::Round($tileW / $aspectRatio)
    $rows = [int][Math]::Ceiling($frames.Count / $cols)

    $fontName = "Microsoft YaHei UI"
    $headerFont = [System.Drawing.Font]::new($fontName, $headerFontSize, [System.Drawing.FontStyle]::Bold)
    $stampFont = [System.Drawing.Font]::new($fontName, $stampFontSize, [System.Drawing.FontStyle]::Bold)
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $borderPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(60, 60, 60), 1)
    # A lighter translucent background keeps the frame visible underneath.
    $stampBack = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(135, 0, 0, 0))

    $file = Get-Item -LiteralPath $videoFile
    $labelFile = Text-FromCodePoints @(25991, 20214, 21517)
    $labelSize = Text-FromCodePoints @(22823, 23567)
    $labelResolution = Text-FromCodePoints @(20998, 36776, 29575)
    $labelVideoCodec = Text-FromCodePoints @(35270, 39057, 35299, 30721, 22120)
    $labelAudioCodec = Text-FromCodePoints @(38899, 39057, 35299, 30721, 22120)
    $labelDuration = Text-FromCodePoints @(26102, 38271)
    $fileLabel = "$labelFile`: "
    $fileName = $file.Name
    $fileLines = New-Object System.Collections.Generic.List[string]
    while ($fileName.Length -gt $maxHeaderChars) {
        $fileLines.Add($fileLabel + $fileName.Substring(0, $maxHeaderChars))
        $fileLabel = ""
        $fileName = $fileName.Substring($maxHeaderChars)
    }
    $fileLines.Add($fileLabel + $fileName)
    $lines = @($fileLines.ToArray()) + @(
        "$labelSize`: $(Format-Size $file.Length)",
        "$labelResolution`: $($meta.Width)x$($meta.Height)($($meta.Fps) fps)",
        "$labelVideoCodec`: $($meta.VideoCodec) $labelAudioCodec`: $($meta.AudioCodec)",
        "$labelDuration`: $(Format-Time $meta.Duration)"
    )
    $headerHeight = [int]($lineHeight * $lines.Count + 18)
    # Calculate the canvas only after filename wrapping has determined the
    # final header height; otherwise the last thumbnail row can be clipped.
    $sheetHeight = $headerHeight + $margin + ($tileH * $rows) + ($gap * ($rows - 1)) + $margin
    $bmp = [System.Drawing.Bitmap]::new($sheetWidth, $sheetHeight)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::White)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        Draw-OutlinedText $g $lines[$i] $headerFont $white 12 ([float](8 + $i * $lineHeight)) 4
    }

    for ($i = 0; $i -lt $frames.Count; $i++) {
        $row = [int][Math]::Floor($i / $cols)
        $col = $i % $cols
        $x = $margin + $col * ($tileW + $gap)
        $y = $headerHeight + $margin + $row * ($tileH + $gap)
        $img = [System.Drawing.Image]::FromFile($frames[$i])
        $g.FillRectangle([System.Drawing.Brushes]::Black, $x, $y, $tileW, $tileH)
        $g.DrawImage($img, $x, $y, $tileW, $tileH)
        $img.Dispose()
        $g.DrawRectangle($borderPen, $x, $y, $tileW, $tileH)

        $stamp = Format-Time $times[$i]
        $size = $g.MeasureString($stamp, $stampFont)
        $padX = 6
        $padY = 3
        # Center the timestamp horizontally at the bottom of each tile.
        $tx = [float]($x + ($tileW - $size.Width) / 2)
        $ty = [float]($y + $tileH - $size.Height - $padY - 2)
        $g.FillRectangle($stampBack, $tx - $padX, $ty - 1, $size.Width + ($padX * 2), $size.Height + $padY)
        Draw-OutlinedText $g $stamp $stampFont $white $tx $ty 4
    }

    $bmp.Save($outputFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    $headerFont.Dispose()
    $stampFont.Dispose()
    $white.Dispose()
    $borderPen.Dispose()
    $stampBack.Dispose()
}

$ffmpeg = Find-Executable "ffmpeg"
$ffprobe = Find-Executable "ffprobe"

$target = Resolve-Path -LiteralPath $Path
$extensions = @(
    ".3g2", ".3gp", ".asf", ".avi", ".divx", ".flv", ".m2ts", ".m4v", ".mkv",
    ".mov", ".mp4", ".mpeg", ".mpg", ".mts", ".ogm", ".ogv", ".rm", ".rmvb",
    ".ts", ".vob", ".webm", ".wmv"
)

$search = if ($Recurse) { "AllDirectories" } else { "TopDirectoryOnly" }
$videos = [System.IO.Directory]::EnumerateFiles($target.Path, "*", $search) |
    Where-Object { $extensions -contains ([IO.Path]::GetExtension($_).ToLowerInvariant()) } |
    Sort-Object

if (-not $videos) {
    Write-Host "No supported video files found in $($target.Path)."
    exit 0
}

$done = 0
foreach ($video in $videos) {
    $out = "$video.png"
    if ((Test-Path -LiteralPath $out) -and -not $Force) {
        Write-Host "Skip existing: $out"
        continue
    }

    Write-Host "Processing: $video"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("vthumb_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        $meta = Get-MediaInfo $ffprobe $video
        if ($meta.Duration -le 0) { throw "Cannot determine video duration." }

        $times = New-Object System.Collections.Generic.List[double]
        $frames = New-Object System.Collections.Generic.List[string]
        for ($i = 1; $i -le $Count; $i++) {
            $t = Get-SampleTime $meta.Duration $i $Count
            $times.Add($t)
            $frame = Join-Path $tmp ("frame_{0:000}.jpg" -f $i)
            $args = @(
                "-hide_banner", "-loglevel", "error",
                "-ss", ($t.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture)),
                "-i", $video,
                "-frames:v", "1",
                # Keep the native aspect ratio.  The sheet uses that same
                # ratio for its tiles, so no padding bars are baked into frames.
                "-vf", "scale=640:-2",
                "-q:v", "3",
                "-y", $frame
            )
            Invoke-Process $ffmpeg $args
            if (Test-Path -LiteralPath $frame) { $frames.Add($frame) }
        }

        Compose-ContactSheet $video $out $frames $times $meta $Width $Cols
        Write-Host "Created: $out"
        $done++
    }
    catch {
        Write-Warning "Failed: $video"
        Write-Warning $_.Exception.Message
    }
    finally {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Recurse -Force
        }
    }
}

Write-Host "Finished. Created $done thumbnail sheet(s)."
