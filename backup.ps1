# Copyright (C) 2019  Marcin Engelmann <mengelmann@octivi.com>

param (
  [parameter(Position=0)][string[]]$commands = @("help"),
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

function showHelp {
  Write-Host "Help"
}

function main {
  $duplicacyTasks = @()

  $repositoryExists = $false
  if ($repository -And (Test-Path -Path "$repository")) {
    if (Test-Path -Path (Join-Path -Path "$repository" -ChildPath ".duplicacy")) {
      $repositoryExists = $true
    }
    else {
      Write-Host "Directory '$repository' exists, but does not look like a Duplicacy backup repository"
      showHelp
      exit
    }
  }
  
  $logDir = Join-Path -Path "$repository" -ChildPath ".duplicacy" | Join-Path -ChildPath "logs"
  $logDirExists = Test-Path -Path "$logDir"
  $logFile = Join-Path -Path "$logDir" -ChildPath ("backup-log-" + $(Get-Date).ToString('yyyyMMdd-HHmmss'))
  if ($repositoryExists -And !$logDirExists) {
    New-Item -ItemType Directory -Path "$logDir"
  }

  switch($commands) {
    cleanLogs {
      if ($logDirExists) {
        Get-ChildItem "$logDir/*" | Where-Object LastWriteTime -LT (Get-Date).AddDays(-$options.keepLogsForDays)
      }
    }

    updateSelf {
      (New-Object System.Net.WebClient).DownloadFile($options.selfUrl, $options.selfFullPath)
    }

    # Duplicacy commands
    backup {
      $duplicacyTasks += $_
    }

    check {
      $duplicacyTasks += $_
    }

    init {
      if (!$repository) {
        Write-Host "Backup repository not provided"
        showHelp
        exit
      }
      elseif ($repositoryExists) {
        Write-Host "Backup repository '$repository' already exists and will not be initialized"
        showHelp
        exit
      }
      else {
        New-Item -ItemType Directory -Path "$repository"
        New-Item -ItemType Directory -Path (Join-Path -Path "$repository" -ChildPath ".duplicacy")
        New-Item -ItemType Directory -Path "$logDir"
      }
      $duplicacyTasks += $_
    }
    
    list {
      $duplicacyTasks += $_
    }

    prune {
      $duplicacyTasks += $_
    }

    default {
      showHelp
      exit
    }
  }

  if ($duplicacyTasks) {
    if ($options.duplicacyDebug) {
      $options.globalOptions += " -debug"
    }
  
    if (!$repositoryExists) {
      Write-Host "Backup repository '$repository' does not exist"
      showHelp
      exit
    }
  
    $pwd = Get-Location
    Set-Location "$repository"
    foreach ($task in $duplicacyTasks) {
      if ($options.ContainsKey($task)) {
        $optionArguments = $options[$task]
      }
      else {
        $optionArguments = ""
      }
      execute $options.duplicacyFullPath ($options.globalOptions,$task,$optionArguments,$remainingArguments -join " ") $logFile
    }
    Set-Location "$pwd"
  }
}

main
