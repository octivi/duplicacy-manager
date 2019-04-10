# Duplicacy Manager

**Work in progress. DO NOT use in production.**

The wrapper on [Duplicacy CLI](https://github.com/gilbertchen/duplicacy/) that allows managing backups efficiently.

Duplicacy CLI (Command Line Interface) is free for personal use and commercial trial. Commercial use of Duplicacy CLI
requires per-user licenses available from [Duplicacy website](https://duplicacy.com/).

## Goals

* Cross-platform – runs on any platform supported by Duplicacy (Linux, MacOS, Windows)
* Convention over configuration – sensible defaults, that may be changed if needed
* Fire&forget – self auto-update and Duplicacy auto-update
* Quiet – bother user only if something went wrong
* Simple, one-file download – self-contained single binary, easy to download and use
* Properly licensed – permission for private and commercial use

## Directory structure

We use [Duplicacy symlink mode](https://forum.duplicacy.com/t/move-duplicacy-folder-use-symlink-repository/1097).
This is the only way to create a repository that includes multiple drives on Windows. Duplicacy will follow the
first-level symlinks (those under the root of the repository). Symlinks located under any subdirectories of the
repository will be backed up as symlinks and will not be followed.

Example directory structure:

```
.
├── backup_repository_1
│   └── .duplicacy
│   │   ├── filters
│   │   ├── logs
│   │   └── preferences
│   ├── C
│   ├── D
|   └── filters -> .duplicacy/filters
├── backup_repository_2
│   └── .duplicacy
│   │   ├── filters
│   │   ├── logs
│   │   └── preferences
|   ├── filters -> .duplicacy/filters
│   └── E
├── backup.exe
├── duplicacy.exe
├── filters.example
└── logs
```
