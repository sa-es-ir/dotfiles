echo hi

# needs install choco first by running blow command
# Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

#choco feature enable -n=allowGlobalConfirmation

# install scripts

#choco install git

#choco install oh-my-posh

#choco feature disable -n=allowGlobalConfirmation

Install-Module -Name z -AllowClobber
Install-Module -Name posh-git
Install-Module -Name PowerShellGet -Force
Update-Module PowerShellGet -Force
Install-Module -Name PSReadLine -Force
# close and open the terminal
Update-Module PSReadLine -Force
Install-Module -Name Terminal-Icons