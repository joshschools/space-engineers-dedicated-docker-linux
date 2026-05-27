# CLAUDE.md

Guidance for working in this repository.

## What this is

A Docker image that runs the Space Engineers Dedicated Server (Windows `.exe`) on Linux via Wine 11. No native Linux SE DS binary exists.

## Common commands

```bash
./seserver install   # first-time appdata + image build
./seserver start [--build] [--no-follow]
./seserver stop | restart | status | logs | build | help
```

Entry point: `seserver` (sources `lib-sudo.sh`). Legacy `./start`, `./stop`, `./restart` exec into `seserver`.

Skip steamcmd on restart: set `SKIP_UPDATE=1` in `.env` (wired through `docker-compose.yml`).

## Architecture

### Build-time (Dockerfile + install-winetricks)

`install-winetricks` runs as `wine` during `docker build`:

1. Xvfb on `:5` with `DISPLAY=:5.0`
2. `wineboot --init` with `mscoree=d` (blocks broken auto-Mono install)
3. Wine Mono MSI from `/usr/share/wine/mono/` (downloaded in Dockerfile as root)
4. winetricks: `corefonts`, `vcrun2019`, `faudio`, `sound=disabled`
5. Python appends `HKLM\...\Installer\Dependencies\Microsoft.VS.VC_RuntimeAdditionalVSU_amd64,v14` to `system.reg`

Does **not** use winetricks `dotnet40`/`dotnet48` — Wine 11 + Wine Mono provides .NET for SE DS.

Ubuntu 24.04 `ubuntu` user (UID 1000) is renamed to `wine` to match `seserver` chown on `appdata/`.

SteamCMD wrapper at `/usr/local/bin/steamcmd` `cd`s to `/home/wine/steamcmd` before `steamcmd.sh`.

### Runtime (entrypoint.bash → entrypoint-space_engineers.bash)

`entrypoint.bash` (root):

- Validates world/cfg (exit 129/130/131)
- Patches `<LoadWorld>` and `<Plugins>` in cfg
- Injects Workshop mods from `mods.txt` into `Sandbox.sbc` / `Sandbox_config.sbc`
- Runs steamcmd AppID 298740 unless `SKIP_UPDATE=1` (with `XDG_RUNTIME_DIR` for wine user)
- Optional Discord log watcher
- `runuser` → `entrypoint-space_engineers.bash`

`entrypoint-space_engineers.bash` (wine):

- `XDG_RUNTIME_DIR=/run/user/1000`
- `WINEDLLOVERRIDES` native for `msvcp140*` / `vcruntime140*`
- Launches `DedicatedServer64/SpaceEngineersDedicated.exe`

### Volume layout

| Host | Container | Purpose |
|---|---|---|
| `appdata/…/config/World/` | `/appdata/space-engineers/World` | World save |
| `appdata/…/config/Plugins/` | `/appdata/space-engineers/Plugins` | Plugin DLLs |
| `appdata/…/config/SpaceEngineers-Dedicated.cfg` | `…/SpaceEngineersDedicated/SpaceEngineers-Dedicated.cfg` | Server config |
| `appdata/…/bins/SpaceEngineersDedicated/` | `/appdata/space-engineers/SpaceEngineersDedicated` | SE DS install |
| `appdata/…/bins/steamcmd/` | `/home/wine/.steam` | Steam cache |
| `appdata/…/config/mods.txt` | `/appdata/space-engineers/mods.txt` | Workshop IDs |

### CI/CD

`.github/workflows/build-push.yml` on push to `main`/`master` → `ghcr.io/<repo>:latest` and `sha-<hash>`. GHA cache is important for winetricks layer reuse.
