# Loaded from $PROFILE (install.ps1 adds the line that dot-sources this file).

Import-Module Terminal-Icons
Import-Module z

# Predictions need an interactive console; skip when output is redirected (scripts, CI, tools)
if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History
}
Set-PSReadLineOption -EditMode Windows

oh-my-posh init pwsh --config jandedobbeleer | Invoke-Expression

# Dot-source so aliases/variables defined there stay in the session
. "$PSScriptRoot\.exports.ps1"
. "$PSScriptRoot\.aliases.ps1"
