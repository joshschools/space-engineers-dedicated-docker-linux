# Space Engineers Dedicated Server (Linux/Docker)

Modernized Docker image for running a Space Engineers Dedicated Server on Linux via Wine. Updated from the unmaintained [mmmaxwwwell/space-engineers-dedicated-docker-linux](https://github.com/mmmaxwwwell/space-engineers-dedicated-docker-linux) project.

**Stack:** Ubuntu 24.04 · Wine 11 (WineHQ stable) · SteamCMD · Docker Compose v2

## Prerequisites

- Docker with the Compose v2 plugin (`docker compose version`)
- `unzip`
- Port `27016/UDP` open on your firewall/router

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

Set `SKIP_UPDATE=1` in the environment to skip the steamcmd update on restart (faster):

```yaml
# docker-compose.yml
environment:
  - SKIP_UPDATE=1
```

## Plugins

Drop `.dll` plugin files into `appdata/space-engineers/config/Plugins/` and restart. The entrypoint auto-injects them into the server config.

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
