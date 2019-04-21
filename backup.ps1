# Copyright (C) 2019  Marcin Engelmann <mengelmann@octivi.com>
[CmdletBinding()]

param (
  [parameter(Position=0, Mandatory=$true)]
  [ValidateSet("help", "cleanLogs", "updateDuplicacy", "updateFilters", "updateSelf", "init", "backup", "check", "list", "prune")]
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
  $repositoryExistsAndInitializedAttributes.Add((New-Object System.Management.Automation.ValidateScriptAttribute({
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
  $repositoryNotExistsAttributes.Add((New-Object System.Management.Automation.ValidateScriptAttribute({
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
      if (-not $paramDictionary.ContainsKey("remainingArguments")) {
        $paramDictionary.Add("remainingArguments", $remainingParameter)
      }
      if (-not $paramDictionary.ContainsKey("storage")) {
        $paramDictionary.Add("storage", $storageParameter)
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
}

Process {

$options = @{
  selfUrl = "https://raw.githubusercontent.com/octivi/duplicacy-manager/powershell/backup.ps1"
  selfFullPath = "$PSCommandPath"
  filtersUrl = "https://raw.githubusercontent.com/TheBestPessimist/duplicacy-utils/master/filters/filters_symlink-to-root-drive-only"
  filtersFullPath = Join-Path -Path "$PSScriptRoot" -ChildPath "filters.example"
  keepLogsForDays = 30
  duplicacyVersion = "2.1.2"
  duplicacyFullPath = Join-Path -Path "$PSScriptRoot" -ChildPath "duplicacy"
  globalOptions = "-log"
  # Enable the Volume Shadow Copy service (Windows and macOS using APFS only).
  enableVSS = $true
  backup = "-stats"
  check = "-stats"
  prune = "-all -keep 0:1825 -keep 30:180 -keep 7:30 -keep 1:7"
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
    [Parameter(Mandatory = $true)][string]$logFile
  )
  $command = $options.duplicacyFullPath
  log "Executing Duplicacy command: '$command $arguments'" DEBUG "$logFile"
  & $command "--%" $arguments *>&1 | Tee-Object -FilePath "$logFile" -Append
  $exitCode = $LASTEXITCODE
  log "Duplicacy finished with exit code: $exitCode" DEBUG "$logFile"
}

function showHelp {
  Write-Output "Help"
}

function log {
  [cmdletbinding()]
  param (
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)][ValidateNotNullOrEmpty()][string]$message, 
    [Parameter(Position=1)][ValidateSet("ERROR","WARN","INFO", "DEBUG")][string]$level="INFO",
    [Parameter(Position=2)][string]$logFile
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
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$repositoryPath
  )

  return (Join-Path -Path "$repositoryPath" -ChildPath ".duplicacy" | Join-Path -ChildPath "logs")
}

function logFilePath {
  param (
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$repositoryPath
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
      # Based on https://forum.duplicacy.com/t/supported-storage-backends/1107
      # and https://forum.duplicacy.com/t/passwords-credentials-and-environment-variables/1094
      $storageEnvs = @()
      $storageEnvs += @{env = "DUPLICACY_PASSWORD"; description = "backup repository encryption password (leave blank for unencrypted backup)"}

      switch -Regex ($storage) {
        '^(azure://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_AZURE_TOKEN"; description = "Azure storage account access key"}
        }
        '^(b2://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_B2_ID"; description = "Backblaze account ID"}
          $storageEnvs += @{env = "DUPLICACY_B2_KEY"; description = "Backblaze application key"}
        }
        '^(dropbox://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_DROPBOX_TOKEN"; description = "Dropbox token"}
        }
        '^(gcs://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_GCS_TOKEN"; description = "Google Cloud Storage token file"}
        }
        '^(gcd://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_GCD_TOKEN"; description = "Google Drive token file"}
        }
        '^(hubic://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_HUBIC_TOKEN"; description = "Hubic token file"}
        }
        '^(one://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_ONE_TOKEN"; description = "Microsoft OneDrive token file"}
        }
        '^(s3://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_S3_ID"; description = "S3 ID"}
          $storageEnvs += @{env = "DUPLICACY_S3_SECRET"; description = "S3 secret"}
        }
        '^(sftp://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_SSH_PASSWORD"; description = "SSH password"}
        }
        '^(wasabi://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_WASABI_KEY"; description = "Wasabi key"}
          $storageEnvs += @{env = "DUPLICACY_WASABI_SECRET"; description = "Wasabi secret"}
        }
        '^(webdav://.+)$' {
          $storageEnvs += @{env = "DUPLICACY_WEBDAV_PASSWORD"; description = "WebDAV password"}
        }
      }

      # Set environmental variables to provide passwords to Duplicacy
      foreach ($storageEnv in $storageEnvs) {
        $response = Read-host "Enter $($storageEnv.description)" -AsSecureString
        $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($response))
        Set-Item env:\$($storageEnv.env) -Value $password
      }

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
      $initArguments = $options.globalOptions,"init",$remainingArguments,$repositoryName,$storage -join " "
      $backupArguments = $options.globalOptions,"backup",$remainingArguments -join " "
      executeDuplicacy $initArguments $logFile
      executeDuplicacy $backupArguments $logFile
      Set-Location "$pwd"

      # Unset environmental variables to remove passwords from memory
      foreach ($storageEnv in $storageEnvs) {
        Remove-Item env:\$($storageEnv.env)
      }

      log "Next steps:" INFO "$logFile"
      log "1. Enter backup repository directory:" INFO "$logFile"
      log "   cd $repositoryFullPath" INFO "$logFile"
      log "2. Add symlinks to folders or disks you want to backup" INFO "$logFile"
      log "   2.1. On Windows, e.g." INFO "$logFile"
      log "      mklink /d C C:\" INFO "$logFile"
      log "      mklink /d D D:\" INFO "$logFile"
      log "   2.1. On Linux, e.g." INFO "$logFile"
      log "      ln -s /home" INFO "$logFile"
      log "   2.3. On MacOS, e.g." INFO "$logFile"
      log "      ln -s /Users" INFO "$logFile"
      log "3. Create your own filters file in '$(Join-Path -Path $duplicacyDirPath -ChildPath filters)'." INFO "$logFile"
      log "   You can use '$($options.filtersFullPath)' as an example. If it does not exist, fetch a new one by executing:" INFO "$logFile"
      log "   $($options.selfFullPath) updateFilters" INFO "$logFile"
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
      $allArguments = $options.globalOptions,$task,$optionArguments,$remainingArguments -join " "
      executeDuplicacy $allArguments $logFile
    }
    Set-Location "$pwd"
  }
}

main
}
