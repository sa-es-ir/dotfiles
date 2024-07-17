echo hi

# needs install choco first

#choco feature enable -n=allowGlobalConfirmation

# install scripts

#choco install git

#choco install oh-my-posh

#choco feature disable -n=allowGlobalConfirmation

#Install-Module -Name z -AllowClobber
Install-Module -Name posh-git
Install-Module -Name PowerShellGet -Force
Update-Module PowerShellGet -Force
Install-Module -Name PSReadLine -Force
Update-Module PSReadLine -Force
Install-Module -Name Terminal-Icons