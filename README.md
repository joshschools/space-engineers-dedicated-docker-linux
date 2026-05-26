# Space Engineers Dedicated Server (Linux/Docker)

Modernized Docker image for running a Space Engineers Dedicated Server on Linux via Wine. Updated from the unmaintained [mmmaxwwwell/space-engineers-dedicated-docker-linux](https://github.com/mmmaxwwwell/space-engineers-dedicated-docker-linux) project.

**Stack:** Ubuntu 24.04 · Wine 11 (WineHQ stable) · SteamCMD · Docker Compose v2

**Features:** Steam Workshop mod support · Plugin DLL support · Auto-updates via SteamCMD · Pre-built image on GHCR

## Prerequisites

- Docker with the Compose v2 plugin (`docker compose version`)
- `unzip`
- Ports `27016/UDP` and `8766/UDP` open on your firewall/router

## Quick Start

```bash
git clone https://github.com/joshschools/space-engineers-dedicated-docker-linux.git
cd space-engineers-dedicated-docker-linux
./start
```

On first run `./start` copies `SpaceEngineers-Dedicated.cfg.template` to `appdata/space-engineers/config/SpaceEngineers-Dedicated.cfg`, then exits and asks you to configure it. Edit the config (add your Steam64 ID at minimum), then run `./start` again.

## Configuration

Edit `appdata/space-engineers/config/SpaceEngineers-Dedicated.cfg`. Key settings:

| Setting | Description |
|---|---|
| `<ServerName>` | Name shown in the server browser |
| `<Administrators><unsignedLong>` | Your Steam64 ID — look it up at [steamid.io](https://steamid.io) |
| `<MaxPlayers>` | Player limit (default 16) |
| `<OnlineMode>` | `PUBLIC`, `PRIVATE`, or `FRIENDS` |
| `<ServerPort>` | UDP port (default 27016) |

## Managing the server

```bash
./start    # start (and update SE DS via steamcmd)
./stop     # stop
./restart  # stop then start
sudo docker compose logs -f   # follow live logs
```

`./stop` gives the server 60 seconds to flush its world save before force-killing it.

Set `SKIP_UPDATE=1` in the environment to skip the steamcmd update on restart (faster):

```yaml
# docker-compose.yml
environment:
  - SKIP_UPDATE=1
```

## Plugins

Drop `.dll` plugin files into `appdata/space-engineers/config/Plugins/` and restart. The entrypoint auto-injects them into the server config.

## Discord Notifications

Create a `.env` file in the project root (gitignored) with your webhook URL:

```
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN
```

Copy `.env.example` as a starting point. Notifications are silently skipped if the URL is not set.

| Event | Message |
|---|---|
| `./start` | 🚀 Server is starting… |
| SE DS "Game ready" | ✅ Server ready — players can connect |
| SE DS auto-restart warning | ⚠️ Auto-restart in N minutes |
| Player count change | 👤 Players online: N |
| `./stop` | 🔴 Server is stopping… |

> Player names on join/leave are not available in the standard SE DS log — player count changes are the best proxy without a plugin or the Remote API.

## Block Limits

Two methods to cap blocks and prevent lag griefing:

**PCU limits** — set in `SpaceEngineers-Dedicated.cfg`:

| Setting | Description |
|---|---|
| `<TotalPCU>` | Global PCU cap across all players (default 320000) |
| `<PiratePCU>` | PCU allocated to NPC/pirate grids (default 50000) |
| `<BlockLimitsEnabled>` | `NONE`, `PCU`, or `PER_PLAYER` |

**Per-block-type limits** — edit `<BlockTypeLimits>` in `SpaceEngineers-Dedicated.cfg`:

```xml
<BlockTypeLimits>
  <dictionary>
    <item><Key>LargeGatlingTurret</Key><Value>10</Value></item>
  </dictionary>
</BlockTypeLimits>
```

## Remote API

SE DS includes a RESTful Remote API (HMAC-SHA1 auth) for external tools including the official VRageRemoteClient.

To enable it, set `<RemoteApiEnabled>true</RemoteApiEnabled>` in `SpaceEngineers-Dedicated.cfg`. Port `8080/TCP` is already exposed in `docker-compose.yml` — open it on your firewall and connect with [VRageRemoteClient](https://www.spaceengineersgame.com/dedicated-servers/).

## Mods (Steam Workshop)

Add Workshop mod IDs to `appdata/space-engineers/config/mods.txt`, one per line:

```
# Find the ID in the Workshop URL: steamcommunity.com/sharedfiles/filedetails/?id=XXXXXXXXXX
1902970975
```

The server downloads mods automatically on startup via its Steam connection. Restart after changing the list.

## Building locally

The pre-built image is pulled automatically. To build from source instead:

```bash
sudo docker compose build   # ~20-30 min first time (dotnet48 installer is slow)
```

## Proxmox notes

Run inside a **KVM VM**, not LXC — Wine requires full virtualization. Recommended:

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 4 cores | 8 cores |
| RAM | 8 GB | 16 GB |
| Disk | 20 GB | 40 GB |

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
| 131 | `SpaceEngineers-Dedicated.cfg` missing — config not in `appdata/space-engineers/config/` |

## Directory structure

```
appdata/
└── space-engineers/
    ├── bins/
    │   ├── SpaceEngineersDedicated/   # server files (downloaded by steamcmd)
    │   └── steamcmd/                  # steam client cache
    └── config/
        ├── SpaceEngineers-Dedicated.cfg
        ├── mods.txt                   # Steam Workshop mod IDs, one per line
        ├── Plugins/                   # drop .dll plugins here
        └── World/                     # world save files
```

## How it works

Space Engineers has no native Linux dedicated server binary. This image runs the Windows `.exe` under Wine with several fixes required to get past startup checks:

- `dotnet48` + `vcrun2019` + `faudio` via winetricks
- `HKLM\...\Classes\Installer\Dependencies\Microsoft.VS.VC_RuntimeAdditionalVSU_amd64,v14` written directly to `system.reg` (SE DS checks this key at startup; winetricks doesn't create it)
- Native DLL overrides forced for all `msvcp140` / `vcruntime140` variants

## Credits

Built on the groundwork of [mmmaxwwwell](https://github.com/mmmaxwwwell/space-engineers-dedicated-docker-linux) and [Devidian](https://github.com/Devidian/docker-spaceengineers).
