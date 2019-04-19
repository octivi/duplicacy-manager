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
  $repositoryExistsAndInitializedParameter = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("repository", [string], $repositoryExistsAndInitializedAttributes)

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
  $repositoryNotExistsParameter = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("repository", [string], $repositoryNotExistsAttributes)

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
      if (-not $paramDictionary.ContainsKey("repository")) {
        $paramDictionary.Add("repository", $repositoryExistsAndInitializedParameter)
      }
    }
    '^(updateDuplicacy|updateFilters|updateSelf)$' {
    }
    '^(backup|check|list|prune)$' {
      if (-not $paramDictionary.ContainsKey("repository")) {
        $paramDictionary.Add("repository", $repositoryExistsAndInitializedParameter)
      }
      if (-not $paramDictionary.ContainsKey("remainingArguments")) {
        $paramDictionary.Add("remainingArguments", $remainingParameter)
      }
    }
    '^init$' {
      if (-not $paramDictionary.ContainsKey("repository")) {
        $paramDictionary.Add("repository", $repositoryNotExistsParameter)
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
  $repository = $PSBoundParameters["repository"]
  $remainingArguments = $PSBoundParameters["remainingArguments"]
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
  duplicacyArchitecture = "win_x64"
  duplicacyFullPath = Join-Path -Path "$PSScriptRoot" -ChildPath "duplicacy"
  globalOptions = "-background -log"
  backup = "-stats -vss"
  check = "-stats"
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
  log "Executing Duplicacy: '$command --% $arg'" DEBUG "$logFile"
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
    [ValidateSet("ERROR","WARN","INFO", "DEBUG")][string]$level="INFO",
    [Alias('LogPath')][string]$logFile
  )

  $date = $(Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  Write-Output "$date $level $message"
  if ($logFile) {
    "$date $level $message" | Out-File -FilePath "$logFile" -Append
  }
}

function logDirPath {
  param (
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$repository
  )

  return (Join-Path -Path (Resolve-Path -Path "$repository") -ChildPath ".duplicacy" | Join-Path -ChildPath "logs")
}

function logFilePath {
  param (
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$repository
  )

  return (Join-Path -Path (logDirPath($repository)) -ChildPath ("backup-log-" + $(Get-Date).ToString('yyyyMMdd-HHmmss')))
}

function main {
  $duplicacyTasks = @()

  $logFile = ""
  if ($repository -and (Test-Path -Path "$repository")) {
    $logFile = logFilePath($repository)
    log "Logging to '$logFile'" INFO "$logFile"
  }

  switch -Regex ($commands) {
    # Our commands
    '^cleanLogs$' {
      if (Test-Path -Path "$logDir") {
        $logDir = logDirPath($repository)
        log "Removing logs older than $($options.keepLogsForDays) day(s) from '$logDir' " INFO "$logFile"
        Get-ChildItem "$logDir/*" | Where-Object LastWriteTime -LT (Get-Date).AddDays(-$options.keepLogsForDays)
      }
      else {
        log "Not cleaning logs, log directory '$logDir' does not exist" ERROR
      }
    }

    '^updateSelf$' {
      log "Updating self from '$($options.selfUrl)' to '$($options.selfFullPath)'" INFO "$logFile"
      (New-Object System.Net.WebClient).DownloadFile($options.selfUrl, $options.selfFullPath)
    }

    '^updateDuplicacy$' {
      $duplicacyUrl = "https://github.com/gilbertchen/duplicacy/releases/download/v$($options.duplicacyVersion)/duplicacy_$($options.duplicacyArchitecture)_$($options.duplicacyVersion)"
      $duplicacyFullPath = $options.duplicacyFullPath
      if ($options.duplicacyArchitecture -match "^win_") {
        $duplicacyUrl += ".exe"
        $duplicacyFullPath += ".exe"
      }
      log "Updating Duplicacy from '$($duplicacyUrl)' to '$duplicacyFullPath'" INFO "$logFile"
      (New-Object System.Net.WebClient).DownloadFile($duplicacyUrl, $duplicacyFullPath)
    }

    '^updateFilters$' {
      log "Updating filters from '$($options.filtersUrl)' to '$($options.filtersFullPath)'" INFO "$logFile"
      (New-Object System.Net.WebClient).DownloadFile($options.filtersUrl, $options.filtersFullPath)
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

      log "Creating directory structure for backup repository '$repository'" INFO
      New-Item -ItemType Directory -Path "$repository"
      $repositoryDir = Resolve-Path -Path "$repository"
      $duplicacyDir = Join-Path -Path "$repositoryDir" -ChildPath ".duplicacy"
      New-Item -ItemType Directory -Path "$duplicacyDir"
      New-Item -ItemType Directory -Path (Join-Path -Path "$duplicacyDir" -ChildPath "logs")
      New-Item -ItemType SymbolicLink -Path (Join-Path -Path "$repositoryDir" -ChildPath "filters.backup") -Target (Join-Path -Path ".duplicacy" -ChildPath "filters")
      $logFile = logFilePath($repository)
      log "Logging to '$logFile'" INFO "$logFile"
      log "Created directory structure for backup repository '$repositoryDir'" INFO "$logFile"

      $pwd = Get-Location
      Set-Location "$repository"
      $repositoryBaseName = (Get-Item -Path $repository).BaseName
      $initArguments = $options.globalOptions,"init",$remainingArguments,$repositoryBaseName,$storage -join " "
      $backupArguments = $options.globalOptions,"backup",$remainingArguments -join " "
      execute $options.duplicacyFullPath $initArguments $logFile
      execute $options.duplicacyFullPath $backupArguments $logFile
      Set-Location "$pwd"

      # Unset environmental variables to remove passwords from memory
      foreach ($storageEnv in $storageEnvs) {
        Remove-Item env:\$($storageEnv.env)
      }

      log "Next steps:" INFO "$logFile"
      log "1. Enter backup repository directory:" INFO "$logFile"
      log "   cd $repositoryDir" INFO "$logFile"
      log "2. Add symlinks to folders or disks you want to backup" INFO "$logFile"
      log "   2.1. On Windows, e.g." INFO "$logFile"
      log "      mklink /d C C:\" INFO "$logFile"
      log "      mklink /d D D:\" INFO "$logFile"
      log "   2.1. On Linux, e.g." INFO "$logFile"
      log "      ln -s /home" INFO "$logFile"
      log "   2.3. On MacOS, e.g." INFO "$logFile"
      log "      ln -s /Users" INFO "$logFile"
      log "3. Create your own filters file in '$(Join-Path -Path $duplicacyDir -ChildPath filters)'." INFO "$logFile"
      log "   You can use '$($options.filtersFullPath)' as an example. If it does not exist, fetch a new one by executing:" INFO "$logFile"
      log "   $($options.selfFullPath) updateFilters" INFO "$logFile"
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
}
