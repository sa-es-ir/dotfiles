Import-Module Terminal-Icons

Set-PSReadLineOption -PredictionSource History

Set-PSReadLineOption -EditMode Windows

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression

oh-my-posh font install

./.exports.ps1
./.aliases.ps1

# copy this file and override on your default profile you can find it here: run $profile in the powershell
 