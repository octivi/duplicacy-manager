# Copyright (C) 2019  Marcin Engelmann <mengelmann@octivi.com>

param (
  [parameter(Position=0)][string]$command = "help",
  [parameter(Position=1)][string]$repository,
  [Parameter(ValueFromRemainingArguments=$true)][string]$remainingArguments
)

$options = @{
  selfUrl = "https://raw.githubusercontent.com/octivi/duplicacy-manager/powershell/backup.ps1"
  selfFullPath = "$PSCommandPath"
  keepLogsForDays = 30
  duplicacyFullPath = Join-Path -Path "$PSScriptRoot" -ChildPath "duplicacy"
  duplicacyDebug = $false
  globalOptions = "-log"
  backup = "-stats -vss"
  check = "-stats"
  init = " -encrypt"
  prune = "-all -keep 0:1825 -keep 30:180 -keep 7:30 -keep 1:7"
}

function execute {
  param (
    [Parameter(Mandatory = $true)][string]$command,
    [Parameter(Mandatory = $true)][string]$arg,
    [Parameter(Mandatory = $true)][string]$logFile
  )
  & $command "--%" $arg *>&1 | Tee-Object -FilePath "$logFile" -Append
}

function main {
  $duplicacyTasks = @()
  switch($command -split '\+') {
    cleanLogs {
      $logDir = Join-Path -Path "$repository" -ChildPath ".duplicacy" | Join-Path -ChildPath "logs"
      if (Test-Path -Path "$logDir") {
        Get-ChildItem "$($logDir)/*" | Where-Object LastWriteTime -LT (Get-Date).AddDays(-$options.keepLogsForDays)
      }
      else {
        Write-Host "Log directory '$logDir' does not exists"
      }
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
    init {
      if (Test-Path -Path "$repository") {
        Write-Host "Repository '$repository' already exists"
        exit
      }
      else {
        New-Item -ItemType Directory -Path "$repository"
        New-Item -ItemType Directory -Path (Join-Path -Path "$repository" -ChildPath ".duplicacy")
        New-Item -ItemType Directory -Path (Join-Path -Path "$repository" -ChildPath ".duplicacy" | Join-Path -ChildPath "logs")
      }
      $duplicacyTasks += $_
    }
    prune {
      $duplicacyTasks += $_
    }
    default {
      Write-Host "Help"
      exit
    }
  }

  if ($duplicacyTasks) {
    if ($options.duplicacyDebug) {
      $options.globalOptions += " -debug"
    }
  
    if (!$repository -Or !(Test-Path -Path "$repository")) {
      Write-Host "Repository '$repository' does not exists"
      exit
    }
  
    $pwd = Get-Location
    Set-Location "$repository"
    $logFile = Join-Path -Path ".duplicacy" -ChildPath "logs" | Join-Path -ChildPath ("backup-log-" + $(Get-Date).ToString('yyyyMMdd-HHmmss'))
    foreach ($task in $duplicacyTasks) {
      execute $options.duplicacyFullPath ($options.globalOptions,$task,$options[$task],$remainingArguments -join " ") $logFile
    }
    Set-Location "$pwd"
  }
}

main
