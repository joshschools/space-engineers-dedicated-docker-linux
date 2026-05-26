# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker image that runs the Space Engineers Dedicated Server (Windows-only `.exe`) on Linux via Wine 11. There is no native Linux SE DS binary — Wine is not a workaround, it's the only option.

## Common commands

```bash
./start      # first run: copies config template and exits; subsequent runs: start server
./stop       # stop the container
./restart    # stop then start
sudo docker compose logs -f   # follow live logs
sudo docker compose build     # build image locally (~20-30 min first time; dotnet48 is slow)
```

To skip the steamcmd update on restart (faster):
```yaml
# docker-compose.yml
environment:
  - SKIP_UPDATE=1
```

## Architecture

### Build-time (Dockerfile + install-winetricks)

The image is built once and the Wine prefix is baked in. `install-winetricks` runs as the `wine` user during `docker build` and:
1. Starts a headless Xvfb display (required by winetricks GUI installers)
2. Installs `dotnet40` → `dotnet48` (order matters: 48 is a patch on 40) → `vcrun2019` → `faudio`
3. Injects a registry key directly into `/wineprefix/system.reg` via Python — SE DS checks `HKLM\SOFTWARE\Classes\Installer\Dependencies\Microsoft.VS.VC_RuntimeAdditionalVSU_amd64,v14` at startup and aborts if it's missing; winetricks creates a *different* key and `wine reg add` has flush-timing issues during build

Ubuntu 24.04 ships an `ubuntu` user at UID 1000, which conflicts with the UID the `start` script chowns `appdata/` to. The Dockerfile renames `ubuntu` → `wine` via `usermod`/`groupmod` rather than creating a new user.

SteamCMD is installed via a wrapper script at `/usr/local/bin/steamcmd` that `cd`s into `/home/wine/steamcmd` before calling `./steamcmd.sh` — necessary because `steamcmd.sh` uses `$(dirname "$0")` for relative paths, which breaks if called via symlink.

### Runtime (entrypoint.bash → entrypoint-space_engineers.bash)

`entrypoint.bash` (runs as root):
- Validates that World, Sandbox.sbc, and cfg exist (exits 129/130/131 on failure)
- Patches `<LoadWorld>` in the cfg to the container-internal path using `sed`
- Builds the `<Plugins>` XML element from any `.dll` files in the Plugins volume
- Runs `steamcmd` to update SE DS (AppID 298740, platform `windows`) unless `SKIP_UPDATE=1`
- Drops to `wine` user to run `entrypoint-space_engineers.bash`

`entrypoint-space_engineers.bash` (runs as wine user):
- Launches `SpaceEngineersDedicated.exe` under Wine with `WINEDLLOVERRIDES` forcing native Microsoft DLLs for all `msvcp140*` and `vcruntime140*` variants — winetricks installs the real PE files but doesn't create the DLL override registry entries

### Volume layout

| Host path | Container path | Purpose |
|---|---|---|
| `appdata/…/config/World/` | `/appdata/space-engineers/World` | World save |
| `appdata/…/config/Plugins/` | `/appdata/space-engineers/Plugins` | Plugin DLLs |
| `appdata/…/config/SpaceEngineers-Dedicated.cfg` | `/appdata/…/SpaceEngineersDedicated/SpaceEngineers-Dedicated.cfg` | Server config |
| `appdata/…/bins/SpaceEngineersDedicated/` | `/appdata/space-engineers/SpaceEngineersDedicated` | SE DS install (steamcmd writes here) |
| `appdata/…/bins/steamcmd/` | `/home/wine/.steam` | Steam client cache |

### CI/CD

`.github/workflows/build-push.yml` triggers on push to `main` or `master`, builds with `docker/build-push-action`, and pushes to `ghcr.io/joshschools/space-engineers-dedicated-docker-linux:latest` plus a `sha-<hash>` tag. GHA layer caching (`type=gha`) is critical — the dotnet48 installer takes 20-30 min without a cache hit.
