# One-time setup for these dotfiles. Run from PowerShell 7:  ./install.ps1
# Safe to re-run: every step skips work that is already done.
$ErrorActionPreference = 'Stop'

# --- oh-my-posh (prompt theme engine) --------------------------------------
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    winget install --id JanDeDobbeleer.OhMyPosh --source winget --exact `
        --accept-package-agreements --accept-source-agreements
    # Refresh PATH so oh-my-posh is usable in this session
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# --- Nerd Font for the prompt icons -----------------------------------------
# After this, set "MesloLGM Nerd Font" as the font in your terminal, e.g. in
# Windows Terminal settings.json:  "profiles": { "defaults": { "font": { "face": "MesloLGM Nerd Font" } } }
oh-my-posh font install Meslo

# --- PowerShell modules ------------------------------------------------------
# PSReadLine and PowerShellGet ship with PowerShell 7, no need to install them.
foreach ($module in 'z', 'Terminal-Icons') {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Install-Module -Name $module -Scope CurrentUser -Repository PSGallery -AllowClobber -Force
    }
}

# --- Copy the profile files into the PowerShell profile folder ---------------
# The profile is self-contained: nothing loads from this repo at shell start.
# Re-run this script after editing the files here to apply the changes.
$profileDir = Split-Path $PROFILE
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null

$source = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
if ((Test-Path $PROFILE) -and
    (Get-FileHash $PROFILE).Hash -ne (Get-FileHash $source).Hash) {
    Copy-Item $PROFILE "$PROFILE.bak" -Force
    Write-Host "Backed up existing profile to $PROFILE.bak"
}
Copy-Item $source $PROFILE -Force

foreach ($file in 'shell-integration_v11.ps1', '.exports.ps1', '.aliases.ps1') {
    Copy-Item (Join-Path $PSScriptRoot $file) $profileDir -Force
}

Write-Host "Done. Profile installed to $profileDir. Open a new terminal to load it."
