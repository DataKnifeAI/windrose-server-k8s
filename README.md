![marketing_assets_banner](https://github.com/user-attachments/assets/b8b4ae5c-06bb-46a7-8d94-903a04595036)
[![GitHub License](https://img.shields.io/github/license/indifferentbroccoli/windrose-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/windrose-server-docker/blob/main/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/indifferentbroccoli/windrose-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/windrose-server-docker/releases)
[![GitHub Repo stars](https://img.shields.io/github/stars/indifferentbroccoli/windrose-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/windrose-server-docker)
[![Discord](https://img.shields.io/discord/798321161082896395?style=for-the-badge&label=Discord&labelColor=5865F2&color=6aa84f)](https://discord.gg/indifferentbroccoli)
[![Docker Pulls](https://img.shields.io/docker/pulls/indifferentbroccoli/windrose-server-docker?style=for-the-badge&color=6aa84f)](https://hub.docker.com/r/indifferentbroccoli/windrose-server-docker)

Game server hosting

Fast RAM, high-speed internet

Eat lag for breakfast

[Try our windrose server hosting free for 2 days!](https://indifferentbroccoli.com/windrose-server-hosting)

## Windrose Dedicated Server Docker

A Docker container for running a Windrose dedicated server using DepotDownloader.

## Server Requirements

|      | Minimum  | Recommended |
|------|----------|-------------|
| CPU  | 2 cores  | 4+ cores    |
| RAM  | 8GB      | 16GB        |
| Storage | 35GB  | 50GB        |

## How to use

Copy the `.env.example` file to a new file called `.env`. Then use either `docker compose` or `docker run`.

### Docker Compose

```yaml
services:
  windrose:
    image: indifferentbroccoli/windrose-server-docker
    restart: unless-stopped
    container_name: windrose
    stop_grace_period: 30s
    env_file:
      - .env
    volumes:
      - ./server-files:/home/steam/server-files
```

Then run:

```shell
docker compose up -d
```

### Docker Run

```shell
docker run -d \
    --restart unless-stopped \
    --name windrose \
    --stop-timeout 30 \
    --env-file .env \
    -v ./server-files:/home/steam/server-files \
    indifferentbroccoli/windrose-server-docker
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| PUID | 1000 | User ID for file permissions |
| PGID | 1000 | Group ID for file permissions |
| UPDATE_ON_START | true | Set to false to skip downloading and validating server files on startup |

## Server Configuration

On first start the server automatically creates two configuration files inside `server-files/`:

- `R5/ServerDescription.json` — server identity, invite code, password, max players, and P2P proxy address.
- `R5/Saved/SaveProfiles/Default/RocksDB/<version>/Worlds/<world-id>/WorldDescription.json` — per-world settings (difficulty, mob multipliers, etc.).

Start and stop the server once to let these files generate, then edit them as needed. All changes require a server restart.

### Connecting to the server

Players connect via an invite code shown in the server console at startup, or found in `server-files/R5/ServerDescription.json` under `InviteCode`. Share this code with players who can then join via **Play → Connect to Server** in-game.

### ServerDescription.json example

```json
{
    "Version": 1,
    "ServerDescription_Persistent": {
        "PersistentServerId": "...",
        "InviteCode": "myfriends",
        "IsPasswordProtected": false,
        "Password": "",
        "Note": "My Windrose Server",
        "WorldIslandId": "...",
        "MaxPlayerCount": 10,
        "P2pProxyAddress": "0.0.0.0"
    }
}
```

> **Note:** Set `P2pProxyAddress` to `0.0.0.0` so the server accepts connections on all network interfaces when running in Docker.

## Volumes

- `/home/steam/server-files` — Server installation files, saves, and configuration

## About

This is a Dockerized version of the Windrose dedicated server.
