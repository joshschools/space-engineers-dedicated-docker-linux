# Space Engineers Dedicated Server (Linux/Docker)

Docker image for running a Space Engineers Dedicated Server on Linux via Wine. Modernized from the unmaintained [mmmaxwwwell/space-engineers-dedicated-docker-linux](https://github.com/mmmaxwwwell/space-engineers-dedicated-docker-linux) project.

**Stack:** Ubuntu 24.04 · Wine 11 (WineHQ stable) · Wine Mono · SteamCMD · Docker Compose v2

**Features:** Steam Workshop mods · Plugin DLLs · Auto-updates via SteamCMD · Pre-built image on [GHCR](https://github.com/joshschools/space-engineers-dedicated-docker-linux/pkgs/container/space-engineers-dedicated-docker-linux)

## Prerequisites

- Docker with the Compose v2 plugin (`docker compose version`)
- `unzip`
- `curl` (optional; only if using Discord webhooks via `.env`)
- Ports `27016/UDP` and `8766/UDP` open on your firewall/router
- Recommended: add your user to the `docker` group (`sudo usermod -aG docker $USER`, then log out/in) so scripts run without a password

## Quick Start

```bash
git clone https://github.com/joshschools/space-engineers-dedicated-docker-linux.git
cd space-engineers-dedicated-docker-linux
./seserver install    # first run: appdata + build image; may exit to edit config
```

Edit `appdata/space-engineers/config/SpaceEngineers-Dedicated.cfg` (add your Steam64 ID to `<Administrators>`), then:

```bash
./seserver start           # start and follow logs
./seserver start --no-follow   # start detached
```

`./seserver` uses `sudo` only when the current user cannot run `docker compose` directly. Legacy `./start`, `./stop`, and `./restart` still work.

## Managing the server

```bash
./seserver install              # first-time: dirs, world, config, build image
./seserver start                # start (steamcmd update unless SKIP_UPDATE=1)
./seserver start --build        # rebuild image, then start
./seserver start --no-follow    # start without tailing logs
./seserver stop                 # graceful stop (60s save window)
./seserver restart              # stop then start
./seserver restart --build --no-follow
./seserver status               # container + log summary
./seserver logs                 # follow live logs
./seserver build                # rebuild image only
./seserver help
```

Set `SKIP_UPDATE=1` in `.env` to skip the steamcmd update on restart (faster after the first install):

```bash
cp .env.example .env
# edit .env: SKIP_UPDATE=1
```

## Configuration

Edit `appdata/space-engineers/config/SpaceEngineers-Dedicated.cfg`. Key settings:

| Setting | Description |
|---|---|
| `<ServerName>` | Name shown in the server browser |
| `<Administrators><unsignedLong>` | Your Steam64 ID — [steamid.io](https://steamid.io) |
| `<MaxPlayers>` | Player limit (default 16) |
| `<OnlineMode>` | `PUBLIC`, `PRIVATE`, or `FRIENDS` |
| `<ServerPort>` | UDP port (default 27016) |

## Plugins

Drop `.dll` plugin files into `appdata/space-engineers/config/Plugins/` and restart. The entrypoint injects them into the server config.

## Discord Notifications

Create a `.env` file (see `.env.example`) with your webhook URL. Notifications are skipped if unset. `./discord` uses `curl` only (no `python3`); failures print a warning and do not block `./seserver start` or `stop`.

| Event | Message |
|---|---|
| `./seserver start` | Server is starting |
| SE DS "Game ready" | Server ready — players can connect |
| SE DS auto-restart warning | Auto-restart countdown |
| Player count change | Players online (from STATISTICS log lines) |
| `./seserver stop` | Server is stopping |

Player names on join/leave are not in the default SE DS log; player count is the best proxy without a plugin or Remote API.

## Block Limits

**PCU limits** — in `SpaceEngineers-Dedicated.cfg`:

| Setting | Description |
|---|---|
| `<TotalPCU>` | Global PCU cap (default 320000) |
| `<PiratePCU>` | NPC/pirate PCU (default 50000) |
| `<BlockLimitsEnabled>` | `NONE`, `PCU`, or `PER_PLAYER` |

**Per-block-type limits** — `<BlockTypeLimits>` in the same file.

## Remote API

Set `<RemoteApiEnabled>true</RemoteApiEnabled>` in the config. Port `8080/TCP` is exposed in `docker-compose.yml`.

## Mods (Steam Workshop)

Add Workshop mod IDs to `appdata/space-engineers/config/mods.txt`, one per line:

```
1902970975
```

Restart after changing the list. Mods are injected into the world `Sandbox.sbc` on startup.

## Building locally

CI publishes `ghcr.io/joshschools/space-engineers-dedicated-docker-linux:latest`. To build on your machine:

```bash
./seserver install
# or: ./seserver build        # ~5–15 min with cache; longer on first build
```

Pin a specific build: `image: ghcr.io/joshschools/space-engineers-dedicated-docker-linux:sha-<commit>` in `docker-compose.yml`.

## Proxmox / VM deployment

Use a **KVM VM**, not LXC — Wine needs full virtualization.

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 4 cores | 8 cores |
| RAM | 8 GB | 16 GB |
| Disk | 20 GB | 40 GB+ |

On the guest VM:

1. Install Docker (Engine + Compose plugin).
2. `sudo usermod -aG docker $USER` and re-login.
3. Clone this repo, run `./seserver install`, configure, `./seserver start`.
4. Forward **27016/udp** and **8766/udp** from your router to the VM.

## Ports

| Port | Protocol | Purpose |
|---|---|---|
| 27016 | UDP | Game traffic |
| 8766 | UDP | Steam networking |
| 8080 | TCP | Remote API (optional) |

## Exit codes

| Code | Reason |
|---|---|
| 129 | World directory missing — check volume mounts |
| 130 | `Sandbox.sbc` missing — world not in `appdata/space-engineers/config/World/` |
| 131 | `SpaceEngineers-Dedicated.cfg` missing |

## Directory structure

```
appdata/
└── space-engineers/
    ├── bins/
    │   ├── SpaceEngineersDedicated/   # server files (steamcmd)
    │   └── steamcmd/                  # Steam client cache
    └── config/
        ├── SpaceEngineers-Dedicated.cfg
        ├── mods.txt
        ├── Plugins/
        └── World/
```

## How it works

Space Engineers has no native Linux dedicated server. This image runs the Windows `.exe` under Wine 11 with:

- **Wine Mono** (explicit install; .NET 4.x for SE DS)
- **vcrun2019** + **faudio** via winetricks
- **VC++ registry key** written to `system.reg` — SE DS checks `Microsoft.VS.VC_RuntimeAdditionalVSU_amd64,v14` at startup
- **Native DLL overrides** for `msvcp140*` / `vcruntime140*` at launch (`WINEDLLOVERRIDES`)

## Credits

Based on [mmmaxwwwell](https://github.com/mmmaxwwwell/space-engineers-dedicated-docker-linux) and [Devidian](https://github.com/Devidian/docker-spaceengineers).
