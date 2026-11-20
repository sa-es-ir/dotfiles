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

# --- Hook profile.ps1 into the PowerShell profile -----------------------------
$hook = ". `"$PSScriptRoot\profile.ps1`""
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
if (-not (Select-String -Path $PROFILE -SimpleMatch $hook -Quiet)) {
    Copy-Item $PROFILE "$PROFILE.bak" -Force
    Add-Content -Path $PROFILE -Value $hook
    Write-Host "Added dotfiles profile to $PROFILE (backup: $PROFILE.bak)"
}

Write-Host 'Done. Open a new terminal to load the profile.'
