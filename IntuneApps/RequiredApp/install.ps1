﻿# ==========================
# Config
# ==========================
$ErrorActionPreference = "Stop"

$LogDir = Join-Path $env:LOCALAPPDATA "IntuneApps\Logs"
$LogFile = "$LogDir\intune-required.log"
$GitDir = Join-Path $env:LOCALAPPDATA "Programs\Git"
$GitExe = Join-Path $GitDir "cmd\git.exe"
$TranscriptStarted = $false

function Log {
    param([string]$msg)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$time - $msg"
}

$TempDir = $env:TEMP

function Test-CommandExists {
    param([string]$cmd)
    $exists = [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
    Log "Check command [$cmd]: $exists"
    return $exists
}

function Test-GitInstalled {
    if (Test-Path -LiteralPath $GitExe -PathType Leaf) {
        Log "Git found: $GitExe"
        return $true
    }

    return (Test-CommandExists "git")
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutFile
    )

    Log "Downloading: $Url → $OutFile"

    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
        Log "Download completed: $OutFile"
    } catch {
        Log "Download FAILED: $_"
        throw
    }
}

function Install-Exe {
    param(
        [string]$File,
        [string]$Arguments
    )

    Log "Installing: $File $Arguments"

    if (!(Test-Path $File)) {
        Log "Installer NOT FOUND: $File"
        throw "Missing installer: $File"
    }

    $process = Start-Process -FilePath $File -ArgumentList $Arguments -Wait -PassThru

    Log "ExitCode: $($process.ExitCode)"

    if ($process.ExitCode -ne 0) {
        throw "Install failed: $File (ExitCode=$($process.ExitCode))"
    }
}

try {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    Start-Transcript -Path $LogFile -Append
    $TranscriptStarted = $true

    Log "TempDir: $TempDir"
    if (!(Test-Path $TempDir)) {
        Log "TempDir does not exist. Creating..."
        New-Item -ItemType Directory -Path $TempDir | Out-Null
    }

    $env:Path = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
        [Environment]::GetEnvironmentVariable('Path', 'User')
    ) -join ';'

    if (-not (Test-GitInstalled)) {
        Log "Installing Git..."

        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest"
        $asset = $rel.assets | Where-Object { $_.name -match '64-bit\.exe$' } | Select-Object -First 1

        if (-not $asset) {
            throw "Cannot find Git installer"
        }

        $gitInstaller = Join-Path $TempDir $asset.name

        Download-File `
            -Url $asset.browser_download_url `
            -OutFile $gitInstaller

        Install-Exe `
            -File $gitInstaller `
            -Arguments "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /DIR=`"$GitDir`""

        if (-not (Test-Path -LiteralPath $GitExe -PathType Leaf)) {
            throw "Git executable not found after installation: $GitExe"
        }

        Log "Git INSTALLED SUCCESSFULLY"
    } else {
        Log "Git already installed — skipping"
    }

    exit 0

} catch {
    Log "ERROR OCCURRED: $_"
    Log "STACK TRACE: $($_.Exception.StackTrace)"
    exit 1

} finally {
    Log "===== INSTALL FINISHED ====="
    if ($TranscriptStarted) {
        Stop-Transcript
    }
}