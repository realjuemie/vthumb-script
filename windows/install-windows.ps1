$ErrorActionPreference = 'Stop'
$toolDir = $PSScriptRoot
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    if (Get-Command winget -ErrorAction SilentlyContinue) { winget install --id Gyan.FFmpeg.Shared --exact --accept-source-agreements --accept-package-agreements }
    else { throw 'FFmpeg is missing and winget is unavailable.' }
}
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @($userPath -split ';' | Where-Object { $_ })
if ($parts -notcontains $toolDir) { [Environment]::SetEnvironmentVariable('Path', (($parts + $toolDir) -join ';'), 'User'); Write-Host "Added $toolDir to user PATH." }
Write-Host 'Windows environment is ready. Open a new terminal window.'
