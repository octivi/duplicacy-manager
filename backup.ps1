# Copyright (C) 2019  Marcin Engelmann <mengelmann@octivi.com>

param (
  [string]$command = "help",
  [string]$repository
)

$options = @{
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
  $tasks = @()
  switch($command -split '\+') {
    help {
      Write-Host "Help"
      exit
    }
    backup {
      $tasks += $_
    }
    check {
      $tasks += $_
    }
    prune {
      $tasks += $_
    }
  }

  if (!$repository -Or !(Test-Path -Path "$repository")) {
    Write-Host "Repository '$($repository)' does not exist"
    exit
  }

  if ($options.duplicacyDebug) {
    $options.globalOptions += " -debug"
  }

  Set-Location "$repository"
  $logFile = Join-Path -Path ".duplicacy" -ChildPath "logs" | Join-Path -ChildPath ("backup-log-" + $(Get-Date).ToString('yyyyMMdd-HHmmss'))
  foreach ($task in $tasks) {
    execute $options.duplicacyFullPath ($options.globalOptions,$task,$options[$task] -join " ") $logFile
  }
}

main
