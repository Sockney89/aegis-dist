<#
  Aegis toolchain installer (Windows x64).

  One-liner:
    irm https://raw.githubusercontent.com/Sockney89/aegis-dist/main/install.ps1 | iex

  When run as a saved script:
    .\install.ps1 [-Version 0.1.0] [-Dir C:\Aegis] [-Cc C:\LLVM\bin\clang.exe] [-Register] [-BaseUrl URL]

  Downloads the latest (or a pinned) release, verifies its SHA-256 against the
  published checksums, extracts it, and adds its bin/ to the user PATH.
#>
[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$Dir = "",
    [string]$Cc = "",
    [switch]$Register,
    [string]$BaseUrl = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Owner        = "Sockney89"
$Repo         = "aegis-dist"
$Triple       = "x86_64-pc-windows-msvc"
$AssetName    = "aegis-$Triple.zip"
$ChecksumName = "aegis-checksums.txt"

if (-not $Dir) { $Dir = Join-Path $env:LOCALAPPDATA "Aegis" }

$base = if ($BaseUrl) { $BaseUrl }
        elseif ($Version) { "https://github.com/$Owner/$Repo/releases/download/v$Version" }
        else { "https://github.com/$Owner/$Repo/releases/latest/download" }

Write-Host "Aegis installer: $AssetName from $base"

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("aegis-install-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $zipPath = Join-Path $tmp $AssetName
    $sumPath = Join-Path $tmp "aegis-checksums.txt"
    Invoke-WebRequest -Uri "$base/$AssetName" -OutFile $zipPath -UseBasicParsing
    Invoke-WebRequest -Uri "$base/$ChecksumName" -OutFile $sumPath -UseBasicParsing

    $expected = $null
    foreach ($line in Get-Content -LiteralPath $sumPath) {
        if ($line -match ('^([0-9a-fA-F]{64})\s+\*?' + [regex]::Escape($AssetName) + '\s*$')) { $expected = $Matches[1]; break }
    }
    if (-not $expected) { throw "no checksum for $($AssetName) in the published checksums" }

    $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    if ($actual.ToLower() -ne $expected.ToLower()) {
        throw "checksum mismatch for $AssetName (expected $expected, got $actual)"
    }
    Write-Host "checksum ok ($actual)"

    if (Test-Path -LiteralPath $Dir) { Remove-Item -LiteralPath $Dir -Recurse -Force }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $Dir -Force

    $bin = Join-Path $Dir "bin"
    if (-not (Test-Path -LiteralPath (Join-Path $bin "compiler.exe"))) {
        throw "unexpected layout: $bin\compiler.exe missing"
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) { $userPath = "" }
    if ($userPath.Split(';') -notcontains $bin) {
        $newPath = if ($userPath.Trim()) { "$userPath;$bin" } else { $bin }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "added to user PATH: $bin"
    }
    $env:Path = "$bin;$env:Path"

    if ($Cc) {
        [Environment]::SetEnvironmentVariable("AEGIS_CC", $Cc, "User")
        $env:AEGIS_CC = $Cc
        Write-Host "set AEGIS_CC=$Cc"
    }

    if ($Register) {
        $reg = Join-Path $Dir "register-opencode.ps1"
        if (Test-Path -LiteralPath $reg) {
            $regArgs = @("-Global")
            if ($Cc) { $regArgs += @("-Cc", $Cc) }
            & powershell -NoProfile -ExecutionPolicy Bypass -File $reg @regArgs
        } else {
            Write-Warning "register-opencode.ps1 not found in $Dir; skipping -Register"
        }
    }

    Write-Host ""
    Write-Host "Aegis installed to $Dir"
    Write-Host "  run:  $bin\compiler.exe --help"
    if (-not $Cc) {
        Write-Host "  note: building an executable needs a clang-compatible C compiler;"
        Write-Host "        set it with:  [Environment]::SetEnvironmentVariable('AEGIS_CC','C:\LLVM\bin\clang.exe','User')"
    }
    Write-Host "  tip : open a new shell so PATH refreshes."
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
