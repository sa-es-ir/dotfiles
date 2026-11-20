# dotfiles

PowerShell 7 setup for Windows: [oh-my-posh](https://ohmyposh.dev) prompt, Meslo Nerd Font,
`Terminal-Icons`, `z` directory jumping and PSReadLine history predictions.

## Install

```powershell
git clone https://github.com/sa-es-ir/dotfiles
cd dotfiles
./install.ps1
```

`install.ps1` installs oh-my-posh (via winget), the Meslo font and the modules, then adds a line to
your `$PROFILE` that loads `profile.ps1` from this folder. It is safe to re-run.

Then set your terminal font to **MesloLGM Nerd Font** (Windows Terminal: `Ctrl+Shift+,`, add
`"font": { "face": "MesloLGM Nerd Font" }` under `profiles.defaults`) and open a new terminal.

This is for **PowerShell 7** (`pwsh`). Windows Terminal defaults to Windows PowerShell 5.1, which uses a
different profile, so set *Settings → Startup → Default profile* to **PowerShell**.

Put your own aliases in `.aliases.ps1` and environment variables in `.exports.ps1`.
