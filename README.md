# Duplicacy Manager

**Work in progress. DO NOT use in production.**

Duplicacy Manager is a PowerShell wrapper on [Duplicacy CLI](https://github.com/gilbertchen/duplicacy/)
that allows managing backups efficiently.

Duplicacy CLI (Command Line Interface) is free for personal use and commercial trial. Commercial use of
Duplicacy CLI requires per-user licenses available from [Duplicacy website](https://duplicacy.com/).

## Project goals

* Cross-platform – runs on any platform supported by Duplicacy (Linux, MacOS, Windows)
* Convention over configuration – sensible defaults that may be changed if needed
* Fire&forget – self auto-update and Duplicacy auto-update
* Quiet – bother user only if something went wrong
* Simple, one-file download – self-contained single binary or script, easy to download and use
* Properly licensed – permission for private and commercial use

## Quick Start

### Windows

1. Execute PowerShell as Administrator (with elevated privileges)
   1. Windows 10

      Windows 10 comes with a Cortana search box in the taskbar. Type `powershell` in the search box
      and click on `Windows PowerShell` on the results and select `Run as administrator`.

2. Create `C:\Backup` directory (folder) and change current directory to it

   ```powershell
   PS C:\WINDOWS\system32> mkdir C:\Backup
   PS C:\WINDOWS\system32> cd C:\Backup
   ```

3. Download Duplicacy Manager script from <https://raw.githubusercontent.com/octivi/duplicacy-manager/powershell/backup.ps1>
   and save it to the newly created `C:\Backup` directory

4. Download Duplicacy CLI binary

   ```powershell
   PS C:\Backup> C:\Backup\backup.ps1 updateDuplicacy
   ```

5. Initialize backup repository

   ```powershell
   PS C:\Backup> C:\Backup\backup.ps1 init <backup repository local path> <storage backend> -encrypt
   ```

   where:
   * `<backup repository local path>` is a relative or absolute backup repository local path
     (the directory is created under `C:\Backup` directory, e.g. `backup`)
   * `<storage backend>` is one of the [supported by Duplicacy storage backends](https://forum.duplicacy.com/t/supported-storage-backends/1107),
    e.g. `sftp://u00000@u00000.your-storagebox.de/duplicacy`

   You will be asked to provide a password to storage backend (and other credentials, depends
   on the selected backend) and password to encrypt the backup.

   For example

   ```powershell
   PS C:\Backup> C:\Backup\backup.ps1 init C:\Backup\backup sftp://u00000@u00000.your-storagebox.de/duplicacy -encrypt
   ```

6. Configure the newly initialized backup repository (remember about filters)

    1. Add first-level symbolic links to folders or disks you want to back up, for example to backup
       `C:\` and `D:\` disks create symbolic links

       ```powershell
       PS C:\Backup> cmd /c mklink /d C:\Backup\backup\C C:\
       PS C:\Backup> cmd /c mklink /d C:\Backup\backup\D D:\
       ```

    2. Update default filters from [TheBestPessimist's duplicacy-utils](https://github.com/TheBestPessimist/duplicacy-utils)

       ```powershell
       PS C:\Backup> C:\Backup\backup.ps1 updateFilters
       ```

    3. Create your own filters file in `C:\Backup\backup\.duplicacy\filters`. You can use `C:\Backup\filters.example`
       as an example

       ```powershell
       PS C:\Backup> copy C:\Backup\filters.example C:\Backup\backup\.duplicacy\filters
       ```

7. Schedule backup with Windows Task Scheduler

    ```powershell
    PS C:\Backup> C:\Backup\backup.ps1 schedule <backup repository local path> <list of commands>
    ```

    where:
    * `<backup repository local path>` is a relative or absolute backup repository local path, e.g. `backup`
    * `list of commands` is a comma-separated list of commands, e.g. `backup,prune,check,cleanLogs`

    For example

    ```powershell
    PS C:\Backup> C:\Backup\backup.ps1 schedule C:\Backup\backup backup,prune,check,cleanLogs
    ```

## Duplicacy manager commands

Usage:

```powershell
backup.ps1 [-commands] <commands> [[-repositoryPath] <backup repository path>] [[-storage] <storage URL>] [[-scheduleCommands] <commands to schedule>] [<Duplicacy arguments...>]
```

where:

* `<commands>` - List of commands to execute separated by single comma ',' (no spaces), e.g. `backup,prune,check,cleanLogs`
* `<backup repository path>` - Relative or absolute backup repository local path, e.g. `C:\Backup\backup`
* `<storage backend URL>` - One of the supported by [Duplicacy storage backends](https://forum.duplicacy.com/t/supported-storage-backends/1107)
* `<commands to schedule>` - Comma-separated list of commands to schedule, e.g. `backup,prune,check,cleanLogs`
* `<Duplicacy arguments>` - Optional [command-specific Duplicacy arguments](https://forum.duplicacy.com/t/duplicacy-user-guide/1197)

### Command `help`

Show this help.

```powershell
backup.ps1 help
```

### Command `cleanLogs`

Clean logs older than 30 days.

```powershell
backup.ps1 cleanLogs <backup repository path>
```

#### Required arguments

* `<backup repository path>` - Relative or absolute backup repository local path, e.g. `C:\Backup\backup`

### Command `schedule`

Schedule list of commands to execute, e.g. `backup,prune,check,cleanLogs`.

```powershell
backup.ps1 schedule <backup repository path> <commands to schedule>
```

#### Required arguments

* `<backup repository path>` - Relative or absolute backup repository local path, e.g. `C:\Backup\backup`
* `<commands to schedule>` - Comma-separated list of commands to schedule, e.g. `backup,prune,check,cleanLogs`

### Command `updateDuplicacy`

Download and update Duplicacy CLI binary from [Duplicacy's GitHub repository](https://github.com/gilbertchen/duplicacy/releases/download/).

```powershell
backup.ps1 updateDuplicacy
```

### Command `updateFilters`

Download and update filters from [TheBestPessimist's GitHub repository](https://raw.githubusercontent.com/TheBestPessimist/duplicacy-utils/master/filters/filters_symlink-to-root-drive-only).

```powershell
backup.ps1 updateFilters
```

### Command `updateSelf`

Download and update self from [our own GitHub repository](https://raw.githubusercontent.com/octivi/duplicacy-manager/powershell/backup.ps1).

```powershell
backup.ps1 updateSelf
```

### Command `init`

Initialize a new repository and storage. Invokes [Duplicacy `init` command](https://forum.duplicacy.com/t/init-command-details/1090).

```powershell
backup.ps1 init <backup repository path> <storage backend> [<Duplicacy init arguments...>]
```

#### Required arguments

* `<backup repository path>` - Relative or absolute backup repository local path, e.g. `C:\Backup\backup`
* `<storage backend URL>` - One of the supported by [Duplicacy storage backends](https://forum.duplicacy.com/t/supported-storage-backends/1107)

#### Optional arguments

* `<Duplicacy init arguments>` - Optional [Duplicacy `init` command arguments](https://forum.duplicacy.com/t/duplicacy-user-guide/1197)

### Command `backup`

Save a snapshot of the repository to the storage. Invokes [Duplicacy `backup` command](https://forum.duplicacy.com/t/backup-command-details/1077).

```powershell
backup.ps1 backup <backup repository path> [<Duplicacy backup arguments...>]
```

#### Required arguments

* `<backup repository path>` - Relative or absolute backup repository local path, e.g. `C:\Backup\backup`

#### Optional arguments

* `<Duplicacy backup arguments>` - Optional [Duplicacy `backup` command arguments](https://forum.duplicacy.com/t/backup-command-details/1077)

### Command `check`

Check the integrity of snapshots. Invokes [Duplicacy `check` command](https://forum.duplicacy.com/t/check-command-details/1081).

```powershell
backup.ps1 check <backup repository path> [<Duplicacy check arguments...>]
```

#### Required arguments

* `<backup repository path>` - Relative or absolute backup repository local path, e.g. `C:\Backup\backup`

#### Optional arguments

* `<Duplicacy check arguments>` - Optional [Duplicacy `check` command arguments](https://forum.duplicacy.com/t/check-command-details/1081)

### Command `list`

List snapshots. Invokes [Duplicacy `list` command](https://forum.duplicacy.com/t/list-command-details/1092).

```powershell
backup.ps1 list <backup repository path> [<Duplicacy list arguments...>]
```

#### Required arguments

* `<backup repository path>` - Relative or absolute backup repository local path, e.g. `C:\Backup\backup`

#### Optional arguments

* `<Duplicacy list arguments>` - Optional [Duplicacy `list` command arguments](https://forum.duplicacy.com/t/list-command-details/1092)

### Command `prune`

Prune snapshots by retention policy ('-all -keep 0:1825 -keep 30:180 -keep 7:30 -keep 1:7'). Invokes [Duplicacy `prune` command](https://forum.duplicacy.com/t/prune-command-details/1005).

```powershell
backup.ps1 prune <backup repository path> [<Duplicacy prune arguments...>]
```

#### Required arguments

* `<backup repository path>` - Relative or absolute backup repository local path, e.g. `C:\Backup\backup`

#### Optional arguments

* `<Duplicacy prune arguments>` - Optional [Duplicacy `prune` command arguments](https://forum.duplicacy.com/t/prune-command-details/1005)

## Directory structure

Duplicacy manager uses [Duplicacy symlink mode](https://forum.duplicacy.com/t/move-duplicacy-folder-use-symlink-repository/1097).
This is the only way to create a repository that includes multiple drives on Windows. Duplicacy follows the
first-level symlinks (those under the root of the repository). Symlinks located under any subdirectories of the
repository are backed up as symlinks and are not followed.

Check [Duplicacy documentation](https://forum.duplicacy.com/t/duplicacy-user-guide/1197).

Example directory structure:

```shell
.
├── backup_repository_1
│   └── .duplicacy
│   │   ├── cache
│   │   ├── filters
│   │   ├── logs
│   │   └── preferences
│   ├── C
│   └── D
├── backup_repository_2
│   └── .duplicacy
│   │   ├── cache
│   │   ├── filters
│   │   ├── logs
│   │   └── preferences
│   └── E
├── backup.ps1
├── duplicacy.exe
└── filters.example
```
