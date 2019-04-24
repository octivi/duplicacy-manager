# Copyright (C) 2019  Marcin Engelmann <mengelmann@octivi.com>
[CmdletBinding()]

param (
  [parameter(Position = 0, Mandatory = $true)]
  [ValidateSet("help", "cleanLogs", "schedule", "updateDuplicacy", "updateFilters", "updateSelf", "init", "backup", "check", "list", "prune")]
  [string[]]
  $commands
)

DynamicParam {
  $repositoryAttribute = New-Object System.Management.Automation.ParameterAttribute
  $repositoryAttribute.Position = 1
  $repositoryAttribute.HelpMessage = "Enter backup repository path"
  $repositoryAttribute.Mandatory = $true

  # Repository parameter required and the directory must exists and the directory is initialized Duplicacy's backup repository
  $repositoryExistsAndInitializedAttributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
  $repositoryExistsAndInitializedAttributes.Add($repositoryAttribute)
  $repositoryExistsAndInitializedAttributes.Add((New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute))
  $repositoryExistsAndInitializedAttributes.Add((New-Object System.Management.Automation.ValidateScriptAttribute( {
          if (-not (Test-Path -Path $_ -PathType Container)) {
            Throw "The '$_' backup repository does not exist."
          }
          elseif (-not (Test-Path -Path (Join-Path -Path $_ -ChildPath ".duplicacy" | Join-Path -ChildPath "preferences") -PathType Leaf)) {
            Throw "The '$_' backup repository does not look like an initialized Duplicacy's backup repository."
          }
          else {
            $true
          }
        })))
  $repositoryExistsAndInitializedParameter = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("repositoryPath", [string], $repositoryExistsAndInitializedAttributes)

  # Repository parameter required and the directory must not exists
  $repositoryNotExistsAttributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
  $repositoryNotExistsAttributes.Add($repositoryAttribute)
  $repositoryNotExistsAttributes.Add((New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute))
  $repositoryNotExistsAttributes.Add((New-Object System.Management.Automation.ValidateScriptAttribute( {
          if (Test-Path -Path $_ -PathType Container) {
            Throw "The '$_' directory already exists."
          }
          else {
            $true
          }
        })))
  $repositoryNotExistsParameter = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("repositoryPath", [string], $repositoryNotExistsAttributes)

  # Storage parameter required (for init command)
  $storageAttribute = New-Object System.Management.Automation.ParameterAttribute
  $storageAttribute.HelpMessage = "Storage URL"
  $storageAttribute.Position = 2
  $storageAttribute.Mandatory = $true
  $storageAttributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
  $storageAttributes.Add($storageAttribute)
  $storageAttributes.Add((New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute))
  $storageParameter = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("storage", [string], $storageAttributes)

  # Command parameter required (for schedule command)
  $commandsAttribute = New-Object System.Management.Automation.ParameterAttribute
  $commandsAttribute.HelpMessage = "Commands to schedule"
  $commandsAttribute.Position = 2
  $commandsAttribute.Mandatory = $true
  $commandsAttributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
  $commandsAttributes.Add($commandsAttribute)
  $commandsAttributes.Add((New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute))
  $commandsParameter = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("scheduleCommands", [string[]], $commandsAttributes)

  # Remaining parameters
  $remainingAttribute = New-Object System.Management.Automation.ParameterAttribute
  $remainingAttribute.HelpMessage = "Remaining parameteres"
  $remainingAttribute.Mandatory = $false
  $remainingAttribute.ValueFromRemainingArguments = $true
  $remainingAttributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
  $remainingAttributes.Add($remainingAttribute)
  $remainingParameter = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("remainingArguments", [string[]], $remainingAttributes)

  $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary

  switch -Regex ($commands) {
    '^cleanLogs$' {
      if (-not $paramDictionary.ContainsKey("repositoryPath")) {
        $paramDictionary.Add("repositoryPath", $repositoryExistsAndInitializedParameter)
      }
    }
    '^schedule$' {
      if (-not $paramDictionary.ContainsKey("repositoryPath")) {
        $paramDictionary.Add("repositoryPath", $repositoryExistsAndInitializedParameter)
      }
      if (-not $paramDictionary.ContainsKey("scheduleCommands")) {
        $paramDictionary.Add("scheduleCommands", $commandsParameter)
      }
    }
    '^(updateDuplicacy|updateFilters|updateSelf)$' {
    }
    '^(backup|check|list|prune)$' {
      if (-not $paramDictionary.ContainsKey("repositoryPath")) {
        $paramDictionary.Add("repositoryPath", $repositoryExistsAndInitializedParameter)
      }
      if (-not $paramDictionary.ContainsKey("remainingArguments")) {
        $paramDictionary.Add("remainingArguments", $remainingParameter)
      }
    }
    '^init$' {
      if (-not $paramDictionary.ContainsKey("repositoryPath")) {
        $paramDictionary.Add("repositoryPath", $repositoryNotExistsParameter)
      }
      if (-not $paramDictionary.ContainsKey("storage")) {
        $paramDictionary.Add("storage", $storageParameter)
      }
      if (-not $paramDictionary.ContainsKey("remainingArguments")) {
        $paramDictionary.Add("remainingArguments", $remainingParameter)
      }
    }
  }

  return $paramDictionary
}

Begin {
  $commands = $PSBoundParameters["commands"]
  $repositoryPath = $PSBoundParameters["repositoryPath"]
  $remainingArguments = $PSBoundParameters["remainingArguments"] -join " "
  $storage = $PSBoundParameters["storage"]
  $scheduleCommands = $PSBoundParameters["scheduleCommands"] -join ","
}

Process {
  $options = @{
    selfUrl           = "https://raw.githubusercontent.com/octivi/duplicacy-manager/powershell/backup.ps1"
    selfFullPath      = "$PSCommandPath"
    filtersUrl        = "https://raw.githubusercontent.com/TheBestPessimist/duplicacy-utils/master/filters/filters_symlink-to-root-drive-only"
    filtersFullPath   = Join-Path -Path "$PSScriptRoot" -ChildPath "filters.example"
    keepLogsForDays   = 30
    duplicacyVersion  = "2.1.2"
    duplicacyFullPath = Join-Path -Path "$PSScriptRoot" -ChildPath "duplicacy"
    globalOptions     = "-log"
    # Enable the Volume Shadow Copy service (Windows and macOS using APFS only).
    enableVSS         = $true
    backup            = "-stats"
    check             = "-stats"
    prune             = "-all -keep 0:1825 -keep 30:180 -keep 7:30 -keep 1:7"
  }

  # By setting $InformationPreference to 'Continue' we ensure any information message is displayed on console.
  $InformationPreference = "Continue"

  function getOSVersion {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
      # PowerShell Core 6.x added three new automatic variables to determine whether PowerShell is running in a given OS: $IsWindows, $IsMacOs, and $IsLinux.
      # https://docs.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-core-60?view=powershell-6
      if ($IsLinux) {
        return "lin"
      }
      elseif ($IsMacOS) {
        return "osx"
      }
      else {
        return "win"
      }
    }
    else {
      # Powershell < 6 is probably on Windows.
      return "win"
    }
  }

  function executeDuplicacy {
    param (
      [Parameter(Mandatory = $true)][string]$arguments,
      [Parameter(Mandatory = $true)][string]$logFile,
      [Parameter(Mandatory = $false)][boolean]$tee = $true
    )

    log "Executing Duplicacy command: '$($options.duplicacyFullPath) $arguments'" DEBUG "$logFile"
    if ($tee) {
      & $options.duplicacyFullPath "--%" $arguments *>&1 | Tee-Object -FilePath "$logFile" -Append
    }
    else {
      & $options.duplicacyFullPath "--%" $arguments *>&1
    }
    $exitCode = $LASTEXITCODE
    log "Duplicacy finished with exit code: $exitCode" DEBUG "$logFile"
  }

  function showHelp {
    Write-Output "
NAME:
   duplicacy-manager - PowerShell wrapper on Duplicacy CLI that allows managing backups efficiently

USAGE:
   backup.ps1 [-commands] <commands> [[-repositoryPath] <backup repository path>] [[-storage] <storage URL>] [[-scheduleCommands] <commands to schedule>] [<Duplicacy arguments...>]

   where:
      <commands> - List of commands separated by single comma ',' (no spaces)
      <backup repository path> - Relative or absolute backup repository local path
      <storage backend> - One of the supported by Duplicacy storage backends (https://forum.duplicacy.com/t/supported-storage-backends/1107)
      <commands to schedule> - Comma-separated list of commands to schedule, e.g. backup,prune,check,cleanLogs
      <Duplicacy arguments> - Optional command-specific Duplicacy arguments (https://forum.duplicacy.com/t/duplicacy-user-guide/1197)

COMMANDS:
   help - Show this help

   cleanLogs <backup repository path> - Clean logs older than $($options.keepLogsForDays) days

   schedule <backup repository path> <list of commands> - Schedule list of commands to execute,
      e.g. 'backup,prune,check,cleanLogs'

   updateDuplicacy - Update Duplicacy binary 
      Downloads from 'https://github.com/gilbertchen/duplicacy/releases/download/v$($options.duplicacyVersion)/duplicacy_$($OSVersion)_x64_$($options.duplicacyVersion)' to '$($options.duplicacyFullPath)'

   updateFilters - Update filters from TheBestPessimist's GitHub repository
      Downloads from '$($options.filtersUrl)' to '$($options.filtersFullPath)'

   updateSelf - Update self from our own GitHub repository
      Downloads from '$($options.selfUrl)' to '$($options.selfFullPath)'

   init <backup repository path> <storage backend> [<Duplicacy arguments...>] - Initialize a new repository and storage
      Duplicacy command https://forum.duplicacy.com/t/init-command-details/1090

   backup <backup repository path> [<Duplicacy arguments...>] - Save a snapshot of the repository to the storage
      Duplicacy command https://forum.duplicacy.com/t/backup-command-details/1077

   check <backup repository path> [<Duplicacy arguments...>] - Check the integrity of snapshots
      Duplicacy command https://forum.duplicacy.com/t/check-command-details/1081

   list <backup repository path> [<Duplicacy arguments...>] - List snapshots
      Duplicacy command https://forum.duplicacy.com/t/list-command-details/1092

   prune <backup repository path> [<Duplicacy arguments...>] - Prune snapshots by retention policy ('$($options.prune)')
      Duplicacy command https://forum.duplicacy.com/t/prune-command-details/1005
"
}

  function log {
    [cmdletbinding()]
    param (
      [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)][ValidateNotNullOrEmpty()][string]$message, 
      [Parameter(Position = 1)][ValidateSet("ERROR", "WARN", "INFO", "DEBUG")][string]$level = "INFO",
      [Parameter(Position = 2)][string]$logFile
    )

    process {
      $timestamp = $(Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
      Write-Output "$timestamp $level $message"
      if ($logFile) {
        "$timestamp $level $message" | Out-File -FilePath "$logFile" -Append
      }
    }
  }

  function logDirPath {
    param (
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$repositoryPath
    )

    return (Join-Path -Path "$repositoryPath" -ChildPath ".duplicacy" | Join-Path -ChildPath "logs")
  }

  function logFilePath {
    param (
      [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$repositoryPath
    )

    return (Join-Path -Path (logDirPath($repositoryPath)) -ChildPath ("backup-log-" + $(Get-Date).ToString('yyyyMMdd-HHmmss')))
  }

  function main {
    $OSVersion = getOSVersion
    $duplicacyTasks = @()
    $logFile = ""
    if ($repositoryPath -and (Test-Path -Path "$repositoryPath")) {
      $repositoryFullPath = Resolve-Path -LiteralPath "$repositoryPath"
      $repositoryName = (Get-Item -Path $repositoryFullPath).BaseName
      $logFile = logFilePath($repositoryFullPath)
      log "Logging to '$logFile'" INFO "$logFile"
    }

    switch -Regex ($commands) {
      # Our commands
      '^cleanLogs$' {
        $logDir = logDirPath($repositoryFullPath)
        log "Removing logs older than $($options.keepLogsForDays) day(s) from '$logDir'" INFO "$logFile"
        Get-ChildItem "$logDir/*" | Where-Object LastWriteTime -LT (Get-Date).AddDays(-$options.keepLogsForDays)
      }

      '^schedule$' {
        switch -Regex ($OSVersion) {
          'win' {
            if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
              # Limit scheduled task name to 190 characters
              $taskName = "Duplicacy backup repository $repositoryName"[0..190] -join ""

              $taskAction = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "-NonInteractive -NoLogo -NoProfile -ExecutionPolicy Bypass -Command `"& '$($options.selfFullPath)' $scheduleCommands '$repositoryFullPath'`""

              # A compromise which hopefully would work on all OS versions - replace the Eternity with something 30 years
              $taskTrigger = New-ScheduledTaskTrigger `
                -Once `
                -At (Get-Date) `
                -RepetitionDuration (New-TimeSpan -Days (365 * 30)) `
                -RepetitionInterval (New-TimeSpan -Hours 4) `
                -RandomDelay (New-TimeSpan -Minutes 10)

              $taskSettings = New-ScheduledTaskSettingsSet `
                -DontStopOnIdleEnd `
                -DontStopIfGoingOnBatteries `
                -RestartInterval (New-TimeSpan -Minutes 5) `
                -RestartCount 10 `
                -MultipleInstances IgnoreNew `
                -StartWhenAvailable

              # Get backup user credentials
              $taskCredentials = Get-Credential `
                -Message "Please enter the username and password of user that will run backup task" `
                -UserName "$env:userdomain\$env:username"

              # Unregister a scheduled task from the Windows Task Scheduler service
              if (Get-ScheduledTask | Where-Object { $_.TaskName -like $taskName }) {
                log "Updating an already scheduled task '$taskName' in the Windows Task Scheduler" INFO "$logFile"
                Set-ScheduledTask `
                  -TaskName $taskName `
                  -Action $taskAction `
                  -Settings $taskSettings `
                  -Trigger $taskTrigger `
                  -User $taskCredentials.UserName `
                  -Password $taskCredentials.GetNetworkCredential().Password
              }
              else {
                log "Scheduling a new task '$taskName' in the Windows Task Scheduler" INFO "$logFile"
                Register-ScheduledTask `
                  -TaskName $taskName `
                  -Action $taskAction `
                  -RunLevel "Highest" `
                  -Settings $taskSettings `
                  -Trigger $taskTrigger `
                  -User $taskCredentials.UserName `
                  -Password $taskCredentials.GetNetworkCredential().Password
              }

              log "Scheduled the task '$taskName', you can verify it using Windows command 'taskschd.msc'" INFO "$logFile"
            }
            else {
              log "Please execute with Administrator privileges" ERROR "$logFile"
            }
          }
          default {
            log "Scheduling task on '$_' architecture is not yet supported" ERROR "$logFile"
          }
        }
        exit
      }

      '^updateDuplicacy$' {
        $duplicacyUrl = "https://github.com/gilbertchen/duplicacy/releases/download/v$($options.duplicacyVersion)/duplicacy_$($OSVersion)_x64_$($options.duplicacyVersion)"
        $duplicacyFullPath = $options.duplicacyFullPath
        if ($OSVersion -eq "win") {
          $duplicacyUrl += ".exe"
          $duplicacyFullPath += ".exe"
        }
        log "Updating Duplicacy from Duplicacy's GitHub repository '$($duplicacyUrl)' to '$duplicacyFullPath'" INFO "$logFile"
        (New-Object System.Net.WebClient).DownloadFile($duplicacyUrl, $duplicacyFullPath)
      }

      '^updateFilters$' {
        log "Updating filters from TheBestPessimist's GitHub repository '$($options.filtersUrl)' to '$($options.filtersFullPath)'" INFO "$logFile"
        (New-Object System.Net.WebClient).DownloadFile($options.filtersUrl, $options.filtersFullPath)
      }

      '^updateSelf$' {
        log "Updating self from our own GitHub repository '$($options.selfUrl)' to '$($options.selfFullPath)'" INFO "$logFile"
        (New-Object System.Net.WebClient).DownloadFile($options.selfUrl, $options.selfFullPath)
      }

      '^init$' {
        log "Creating directory structure for backup repository '$repositoryPath'" INFO
        New-Item -ItemType Directory -Path "$repositoryPath"
        $repositoryFullPath = Resolve-Path -LiteralPath "$repositoryPath"
        $repositoryName = (Get-Item -Path $repositoryPath).BaseName
        $duplicacyDirPath = Join-Path -Path "$repositoryFullPath" -ChildPath ".duplicacy"
        New-Item -ItemType Directory -Path "$duplicacyDirPath"
        New-Item -ItemType Directory -Path (Join-Path -Path "$duplicacyDirPath" -ChildPath "logs")
        # Creating a symbolic link to a non existent file fails on Windows
        if ($OSVersion -ne "win") {
          New-Item -ItemType SymbolicLink -Path (Join-Path -Path "$repositoryFullPath" -ChildPath "filters.backup") -Target (Join-Path -Path ".duplicacy" -ChildPath "filters")
        }
        $logFile = logFilePath($repositoryFullPath)
        log "Logging to '$logFile'" INFO "$logFile"
        log "Created directory structure for backup repository '$repositoryName' in '$repositoryFullPath'" INFO "$logFile"

        $pwd = Get-Location
        Set-Location "$repositoryPath"
        $initArguments = $options.globalOptions, "init", $remainingArguments, $repositoryName, $storage -join " "
        $backupArguments = $options.globalOptions, "backup" -join " "
        executeDuplicacy $initArguments $logFile -tee $false
        executeDuplicacy $backupArguments $logFile -tee $false
        Set-Location "$pwd"

        switch ($OSVersion) {
          'lin' {
            log "Next steps:" INFO "$logFile"
            log "1. Enter backup repository directory:" INFO "$logFile"
            log "      $ cd $repositoryFullPath" INFO "$logFile"
            log "2. Add symlinks to folders or disks you want to backup" INFO "$logFile"
            log "      $ sudo ln -s /home" INFO "$logFile"
            log "3. Create your own filters file in '$(Join-Path -Path $duplicacyDirPath -ChildPath filters)'." INFO "$logFile"
            log "   You can use '$($options.filtersFullPath)' as an example." INFO "$logFile"
            log "   If it does not exist, fetch a new one by executing:" INFO "$logFile"
            log "      $ $($options.selfFullPath) updateFilters" INFO "$logFile"
          }
          'osx' {
            log "Next steps:" INFO "$logFile"
            log "1. Enter backup repository directory:" INFO "$logFile"
            log "      $ cd $repositoryFullPath" INFO "$logFile"
            log "2. Add symlinks to folders or disks you want to backup" INFO "$logFile"
            log "      $ sudo ln -s /Users" INFO "$logFile"
            log "3. Create your own filters file in '$(Join-Path -Path $duplicacyDirPath -ChildPath filters)'." INFO "$logFile"
            log "   You can use '$($options.filtersFullPath)' as an example." INFO "$logFile"
            log "   If it does not exist, fetch a new one by executing:" INFO "$logFile"
            log "      > $($options.selfFullPath) updateFilters" INFO "$logFile"
          }
          'win' {
            log "Next steps:" INFO "$logFile"
            log "1. Enter backup repository directory:" INFO "$logFile"
            log "      PS C:\> cd $repositoryFullPath" INFO "$logFile"
            log "2. Add symlinks to folders or disks you want to backup" INFO "$logFile"
            log "      PS C:\> cmd /c mklink /d C C:\" INFO "$logFile"
            log "      PS C:\> cmd /c mklink /d D D:\" INFO "$logFile"
            log "3. Create your own filters file in '$(Join-Path -Path $duplicacyDirPath -ChildPath filters)'." INFO "$logFile"
            log "   You can use '$($options.filtersFullPath)' as an example." INFO "$logFile"
            log "   If it does not exist, fetch a new one by executing:" INFO "$logFile"
            log "      PS C:\> $($options.selfFullPath) updateFilters" INFO "$logFile"
          }
        }
      }

      # Other Duplicacy commands
      '^(backup|check|list|prune)$' {
        log "Scheduled executing '$_' command for backup repository '$repositoryName'" INFO "$logFile"
        $duplicacyTasks += $_

        if (($_ -eq "backup") -and $options.enableVSS) {
          if (($OSVersion -eq "osx") -or (($OSVersion -eq "win") -and ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))) {
            # Volume Shadow Copy is supported on Windows when executed with Administrator privileges.
            # Volume Shadow Copy is supported on macOS using APFS only.
            $options.backup += " -vss"
            log "Enabling Volume Shadow Copy (VSS) for 'backup' command" INFO "$logFile"
          }
        }
      }

      default {
        showHelp
        exit
      }
    }

    if ($duplicacyTasks) {
      $pwd = Get-Location
      Set-Location "$repositoryPath"
      foreach ($task in $duplicacyTasks) {
        if ($options.ContainsKey($task)) {
          $optionArguments = $options[$task]
        }
        else {
          $optionArguments = ""
        }
        $allArguments = $options.globalOptions, $task, $optionArguments, $remainingArguments -join " "
        executeDuplicacy $allArguments $logFile
      }
      Set-Location "$pwd"
    }
  }

  main
}
