#!/bin/bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SERVER_DIR=/appdata/space-engineers/SpaceEngineersDedicated/DedicatedServer64
SERVER_EXE="$SERVER_DIR/SpaceEngineersDedicated.exe"

[ -d "$SERVER_DIR" ] || die "DedicatedServer64 directory not found at $SERVER_DIR — did steamcmd finish successfully?"
[ -f "$SERVER_EXE" ] || die "SpaceEngineersDedicated.exe not found at $SERVER_EXE — did steamcmd finish successfully?"

cd "$SERVER_DIR"
env WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree=n,b;mshtml=n,b;msvcp140=n,b;msvcp140_1=n,b;msvcp140_2=n,b;vcruntime140=n,b;vcruntime140_1=n,b" \
    WINEPREFIX=/wineprefix \
  wine "$SERVER_EXE" -noconsole -path Z:\\appdata\\space-engineers\\SpaceEngineersDedicated -ignorelastsession \
  || die "SpaceEngineersDedicated.exe exited with error (exit code $?)"
