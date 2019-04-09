# Copyright (C) 2019  Marcin Engelmann <mengelmann@octivi.com>

param (
  [parameter(Position=0)][string[]]$commands = @("help"),
  [parameter(Position=1)][string]$repository,
  [Parameter(ValueFromRemainingArguments=$true)][string]$remainingArguments
)

$options = @{
  selfUrl = "https://raw.githubusercontent.com/octivi/duplicacy-manager/powershell/backup.ps1"
  selfFullPath = "$PSCommandPath"
  filtersUrl = "https://raw.githubusercontent.com/TheBestPessimist/duplicacy-utils/master/filters/filters_symlink-to-root-drive-only"
  keepLogsForDays = 30
  duplicacyVersion = "2.1.2"
  duplicacyArchitecture = "win_x64"
  duplicacyFullPath = Join-Path -Path "$PSScriptRoot" -ChildPath "duplicacy"
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
  log "Executing Duplicacy: '$($options.duplicacyFullPath) $allArguments'" DEBUG "$logFile"
  & $command "--%" $arg *>&1 | Tee-Object -FilePath "$logFile" -Append
  $exitCode = $LASTEXITCODE
  log "Duplicacy finished with exit code: $exitCode" DEBUG "$logFile"
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

  $repositoryDir = ""
  $repositoryDirExists = $false
  $repositoryInitialized = $false
  $logDir = ""
  $logDirExists = $false
  $logFile = ""

  if ($repository) {
    $repositoryDirExists = Test-Path -Path "$repository"
  
    if ($repositoryDirExists) {
      $repositoryDir = (Resolve-Path -Path "$repository")
      $repositoryInitialized = Test-Path -Path (Join-Path -Path "$repositoryDir" -ChildPath ".duplicacy")

      if ($repositoryInitialized) {
        $logDir = Join-Path -Path "$repositoryDir" -ChildPath ".duplicacy" | Join-Path -ChildPath "logs"
        $logDirExists = Test-Path -Path "$logDir"

        if (-not $logDirExists) {
          New-Item -ItemType Directory -Path "$logDir"
          $logDirExists = Test-Path -Path "$logDir"
        }

        $logFile = Join-Path -Path "$logDir" -ChildPath ("backup-log-" + $(Get-Date).ToString('yyyyMMdd-HHmmss'))
        log "Logging to '$logFile'" INFO "$logFile"
      }
      else {
        log "Directory '$repositoryDir' exists, but does not look like a Duplicacy backup repository" ERROR
        showHelp
        exit
      }
    }
  }
  
  switch -Regex ($commands) {
    # Our commands
    '^cleanLogs$' {
      if ($logDirExists) {
        log "Removing logs older than $($options.keepLogsForDays) day(s) from '$logDir' " INFO "$logFile"
        Get-ChildItem "$logDir/*" | Where-Object LastWriteTime -LT (Get-Date).AddDays(-$options.keepLogsForDays)
      }
      else {
        log "Not cleaning logs, log directory '$logDir' does not exist" DEBUG
      }
    }

    '^updateSelf$' {
      log "Updating self from '$($options.selfUrl)' to '$($options.selfFullPath)'" INFO "$logFile"
      (New-Object System.Net.WebClient).DownloadFile($options.selfUrl, $options.selfFullPath)
    }

    '^updateDuplicacy$' {
      $duplicacyUrl = "https://github.com/gilbertchen/duplicacy/releases/download/v$($options.duplicacyVersion)/duplicacy_$($options.duplicacyArchitecture)_$($options.duplicacyVersion).exe"
      $duplicacyFullPath = $options.duplicacyFullPath
      if ($options.duplicacyArchitecture -match "^win_") {
        $duplicacyFullPath += ".exe"
      }
      log "Updating Duplicacy from '$($duplicacyUrl)' to '$duplicacyFullPath'" INFO "$logFile"
      (New-Object System.Net.WebClient).DownloadFile($duplicacyUrl, $duplicacyFullPath)
    }

    '^updateFilters$' {
      $filtersFullPath = Join-Path -Path "$PSScriptRoot" -ChildPath "filters"
      log "Updating filters from '$($options.filtersfUrl)' to '$($filtersFullPath)'" INFO "$logFile"
      (New-Object System.Net.WebClient).DownloadFile($options.filtersUrl, $filtersFullPath)
    }

    # Special case for "init" command, that is a little different than other commands:
    # requires that repository is provided, but does not exist and does not allow stacking
    # with other commands.
    '^init$' {
      if ($repository) {
        if ($repositoryInitialized) {
          log "Backup repository '$repositoryDir' already initialized" ERROR "$logFile"
          showHelp
        }
        elseif ($repositoryDirExists) {
          log "Directory '$repositoryDir' already exists" ERROR
          showHelp
        }
        else {
          log "Creating directory structure for backup repository '$repository'" INFO
          New-Item -ItemType Directory -Path "$repository"
          $repositoryDir = (Resolve-Path -Path "$repository")
          $duplicacyDir = Join-Path -Path "$repositoryDir" -ChildPath ".duplicacy"
          New-Item -ItemType Directory -Path "$duplicacyDir"
          New-Item -ItemType Directory -Path (Join-Path -Path "$duplicacyDir" -ChildPath "logs")
          log "Created directory structure for backup repository '$repositoryDir'" INFO "$logFile"
          log "Next steps:" INFO "$logFile"
          log "1. Enter backup repository directory:" INFO "$logFile"
          log "   cd $repositoryDir" INFO "$logFile"
          log "2. Add symlinks to folders or disks you want to backup" INFO "$logFile"
          log "   2.1. On Windows, e.g." INFO "$logFile"
          log "      mklink /d C C:\" INFO "$logFile"
          log "      mklink /d D D:\" INFO "$logFile"
          log "   2.1. On Linux, e.g." INFO "$logFile"
          log "      ln -s /home" INFO "$logFile"
          log "      ln -s /media/data" INFO "$logFile"
          log "   2.3. On MacOS, e.g." INFO "$logFile"
          log "      ln -s /Users" INFO "$logFile"
          log "3. Create your own or fetch filters file from" INFO "$logFile"
          log "   https://raw.githubusercontent.com/TheBestPessimist/duplicacy-utils/master/filters/filters_symlink-to-root-drive-only" INFO "$logFile"
          log "   and save it as $(Join-Path -Path "$duplicacyDir" -ChildPath "filters") file" INFO "$logFile"
          log "4. Initialize Duplicacy repository (fast)" INFO "$logFile"
          log "   $($options.duplicacyFullPath) $($options.globalOptions) init $($options.init) -repository '$repositoryDir' -pref-dir '$duplicacyDir' backup <storage url>" INFO "$logFile"
          log "5. Make first backup (time depends on the size of source files and connection speed" INFO "$logFile"
          log "   $($options.duplicacyFullPath) $($options.globalOptions) backup $($options.backup)" INFO "$logFile"
        }
      }
      else {
        log "Backup repository name not provided" ERROR
        showHelp
      }
      exit
    }

    # Other Duplicacy commands
    '^(backup|check|list|prune)$' {
      log "Running '$_' command" INFO "$logFile"
      $duplicacyTasks += $_
    }

    default {
      showHelp
      exit
    }
  }

  if ($duplicacyTasks) {
    if (-not $repository) {
      log "Backup repository name not provided" ERROR
      showHelp
      exit
    }
    elseif (-not $repositoryDirExists) {
      log "Backup repository '$repository' does not exist" ERROR
      showHelp
      exit
    }
    elseif (-not $repositoryInitialized) {
      log "Backup repository '$repositoryDir' exists, but does not look like a Duplicacy backup repository" ERROR
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
