# Copyright (C) 2019  Marcin Engelmann <mengelmann@octivi.com>

param (
  [string]$command = "help",
  [string]$repository
)

$options = @{
  selfUrl = "https://raw.githubusercontent.com/octivi/duplicacy-manager/powershell/backup.ps1"
  selfFullPath = Join-Path -Path "$($PSScriptRoot)" -ChildPath "backup.ps1"
  duplicacyFullPath = Join-Path -Path "$($PSScriptRoot)" -ChildPath "duplicacy"
  duplicacyDebug = $false
  globalOptions = "-log"
  backup = "-stats -vss"
  check = "-stats"
  prune = "-all -keep 0:1825 -keep 30:180 -keep 7:30 -keep 1:7"
}

function execute($command, $arg, $logFile) {
  & $command "--%" $arg *>&1 | Tee-Object -FilePath "$logFile" -Append
}

function main {
  $duplicacyTasks = @()
  switch($command -split '\+') {
    help {
      Write-Host "Help"
      exit
    }

    updateSelf {
      (New-Object System.Net.WebClient).DownloadFile($options.selfUrl, $options.selfFullPath)
      break
    }

    # Duplicacy commands
    backup {
      $duplicacyTasks += $_
    }
    check {
      $duplicacyTasks += $_
    }
    prune {
      $duplicacyTasks += $_
    }
  }

  if ($duplicacyTasks) {
    if ($options.duplicacyDebug) {
      $options.globalOptions += " -debug"
    }
  
    if (!$repository -Or !(Test-Path -Path "$repository")) {
      Write-Host "Repository '$($repository)' does not exist"
      exit
    }
  
    Set-Location "$repository"
    $logFile = Join-Path -Path ".duplicacy" -ChildPath "logs" | Join-Path -ChildPath ("backup-log-" + $(Get-Date).ToString('yyyyMMdd-HHmmss'))
    foreach ($task in $duplicacyTasks) {
      execute $options.duplicacyFullPath ($options.globalOptions,$task,$options[$task] -join " ") $logFile
    }
  }
}

main
