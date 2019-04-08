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

# By setting $InformationPreference to 'Continue' we ensure any information message is displayed on console.
$InformationPreference = "Continue"

function execute {
  param (
    [Parameter(Mandatory = $true)][string]$command,
    [Parameter(Mandatory = $true)][string]$arg,
    [Parameter(Mandatory = $true)][string]$logFile
  )
  log "Executing Duplicacy: '$($options.duplicacyFullPath) $allArguments'" DEBUG "$logfile"
  & $command "--%" $arg *>&1 | Tee-Object -FilePath "$logFile" -Append
  $exitCode = $LASTEXITCODE
  log "Duplicacy finished with exit code: $exitCode" DEBUG "$logfile"
}

function showHelp {
  Write-Output "Help"
}

function log {
  param (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)][ValidateNotNullOrEmpty()][Alias("LogContent")][string]$message, 
    [Parameter(Mandatory=$false)][ValidateSet("ERROR","WARN","INFO", "DEBUG")][string]$level="INFO",
    [Parameter(Mandatory=$false)][Alias('LogPath')][string]$logFile
  )

  $date = $(Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  "$date $level $message"
  if ($logFile) {
    "$date $level $message" | Out-File -FilePath "$logFile" -Append
  }
}

function main {
  $duplicacyTasks = @()

  $repositoryExists = $false
  if ($repository -And (Test-Path -Path "$repository")) {
    if (Test-Path -Path (Join-Path -Path "$repository" -ChildPath ".duplicacy")) {
      $repositoryExists = $true
    }
    else {
      log "Directory '$repository' exists, but does not look like a Duplicacy backup repository" ERROR
      showHelp
      exit
    }
  }
  
  $logDirExists = $false
  if ($repositoryExists) {
    $logDir = Join-Path -Path (Resolve-Path -Path "$repository") -ChildPath ".duplicacy" | Join-Path -ChildPath "logs"
    $logDirExists = Test-Path -Path "$logDir"
    $logFile = Join-Path -Path "$logDir" -ChildPath ("backup-log-" + $(Get-Date).ToString('yyyyMMdd-HHmmss'))
    if (-not $logDirExists) {
      New-Item -ItemType Directory -Path "$logDir"
    }
    log "Logging to '$logFile'" INFO "$logfile"
  }

  switch($commands) {
    cleanLogs {
      if ($logDirExists) {
        log "Cleaning logs older than $($options.keepLogsForDays) days" INFO "$logfile"
        Get-ChildItem "$logDir/*" | Where-Object LastWriteTime -LT (Get-Date).AddDays(-$options.keepLogsForDays)
      }
      else {
        log "Not cleaning logs, log directory '$logDir' does not exist" DEBUG
      }
    }

    updateSelf {
      (New-Object System.Net.WebClient).DownloadFile($options.selfUrl, $options.selfFullPath)
    }

    # Duplicacy commands
    backup {
      log "Backup" INFO
      $duplicacyTasks += $_
    }

    check {
      log "Check" INFO
      $duplicacyTasks += $_
    }

    init {
      if (-not $repository) {
        log "Backup repository not provided" ERROR
        showHelp
        exit
      }
      elseif ($repositoryExists) {
        log "Backup repository '$repository' already exists and will not be initialized" ERROR
        showHelp
        exit
      }
      else {
        log "Creating directories for backup repository '$repository'" INFO
        New-Item -ItemType Directory -Path "$repository"
        New-Item -ItemType Directory -Path (Join-Path -Path "$repository" -ChildPath ".duplicacy")
        New-Item -ItemType Directory -Path "$logDir"
      }
      $duplicacyTasks += $_
    }
    
    list {
      log "List" INFO
      $duplicacyTasks += $_
    }

    prune {
      log "Prune" INFO
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
  
    if (-not $repositoryExists) {
      log "Backup repository '$repository' does not exist" ERROR
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
      $allArguments = $options.globalOptions,$task,$optionArguments,$remainingArguments -join " "
      execute $options.duplicacyFullPath $allArguments $logFile
    }
    Set-Location "$pwd"
  }
}

main
