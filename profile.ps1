Import-Module Terminal-Icons

Set-PSReadLineOption -PredictionSource History

Set-PSReadLineOption -EditMode Windows

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression

oh-my-posh font install meslo

#Once you have installed a Nerd Font, you will need to configure the Windows Terminal to use it. This can be easily done by modifying the Windows Terminal settings (default shortcut: CTRL + SHIFT + ,). In your settings.json file, add the font.face attribute under the defaults attribute in profiles:

#{
#    "profiles":
#    {
#        "defaults":
#        {
#            "font":
#            {
#                "face": "MesloLGM Nerd Font"
#            }
#        }
#    }
#}

./.exports.ps1
./.aliases.ps1

# copy this file and override on your default profile you can find it here: run $profile in the powershell
