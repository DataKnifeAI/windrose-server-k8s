#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

LogAction "Set file permissions"

if [ -z "${PUID}" ] || [ -z "${PGID}" ]; then
    LogError "PUID and PGID not set. Please set these in the environment variables."
    exit 1
else
    usermod -o -u "${PUID}" steam
    groupmod -o -g "${PGID}" steam
fi

# Avoid recursive chown on /home/steam: server-files is often an NFS PVC where chown fails (root_squash)
# and root-owned game files prevent the steam user from writing ServerDescription.json.
chown_steam_best_effort /home/steam/server
chown_steam_best_effort /home/steam/.wine

cat /branding

# If a previous run created .DepotDownloader as root, steam cannot write depot.config (NFS / root_squash).
prepare_depotdownloader_cache() {
    local dd="/home/steam/server-files/.DepotDownloader"
    [ -e "$dd" ] || return 0
    if command -v runuser >/dev/null 2>&1; then
        if runuser -u steam -- test -w "$dd" 2>/dev/null; then
            return 0
        fi
    elif su - steam -s /bin/sh -c "test -w '$dd'" 2>/dev/null; then
        return 0
    fi
    LogWarn "Removing unreadable $dd (e.g. root-owned) so DepotDownloader can recreate it as steam"
    rm -rf "$dd"
}

if [ "${UPDATE_ON_START:-true}" = "true" ]; then
    prepare_depotdownloader_cache
    if ! install; then
        LogError "Server install failed — fix PVC permissions or remove stale .DepotDownloader, then restart"
        exit 1
    fi
else
    LogWarn "UPDATE_ON_START is set to false, skipping server update"
fi

if [ "${UE4SS_ENABLED:-false}" = "true" ] && [ "${WINDROSE_PLUS_ENABLED:-false}" != "true" ]; then
    LogAction "Installing/updating UE4SS"
    SERVER_FILES=/home/steam/server-files /home/steam/server/install_ue4ss.sh
fi

if [ "${WINDROSE_PLUS_ENABLED:-false}" = "true" ]; then
    LogAction "Installing/updating Windrose+"
    export WINDROSE_PLUS_VERSION="${WINDROSE_PLUS_VERSION:-$WINDROSE_PLUS_VERSION_DEFAULT}"
    export WINDROSE_PLUS_RCON_PASSWORD="${WINDROSE_PLUS_RCON_PASSWORD:-}"
    SERVER_FILES=/home/steam/server-files /home/steam/server/install_windrose_plus.sh
else
    LogInfo "Windrose+ disabled (set WINDROSE_PLUS_ENABLED=true to enable)"
fi

chown_steam_best_effort /home/steam/server-files

# shellcheck disable=SC2317
term_handler() {
    if ! shutdown_server; then
        local pid
        pid=$(pgrep -f "wineserver64" | head -1)
        if [ -n "$pid" ]; then
            kill -SIGTERM "$pid"
        fi
    fi
    sleep 2
    tail --pid="$killpid" -f 2>/dev/null
}

trap 'term_handler' SIGTERM

export INVITE_CODE="${INVITE_CODE:-}"
export USE_DIRECT_CONNECTION="${USE_DIRECT_CONNECTION:-false}"
export SERVER_PORT="${SERVER_PORT:-7777}"
export DIRECT_CONNECTION_PROXY_ADDRESS="${DIRECT_CONNECTION_PROXY_ADDRESS:-0.0.0.0}"
export USER_SELECTED_REGION="${USER_SELECTED_REGION:-}"
export SERVER_NAME="${SERVER_NAME:-}"
export SERVER_PASSWORD="${SERVER_PASSWORD:-}"
export MAX_PLAYERS="${MAX_PLAYERS:-10}"
export P2P_PROXY_ADDRESS="${P2P_PROXY_ADDRESS:-}"
export GENERATE_SETTINGS="${GENERATE_SETTINGS:-true}"
export UE4SS_ENABLED="${UE4SS_ENABLED:-false}"
export WINDROSE_PLUS_ENABLED="${WINDROSE_PLUS_ENABLED:-false}"
export WINDROSE_PLUS_VERSION="${WINDROSE_PLUS_VERSION:-$WINDROSE_PLUS_VERSION_DEFAULT}"
export WINDROSE_PLUS_DASHBOARD_PORT="${WINDROSE_PLUS_DASHBOARD_PORT:-8780}"
export WINDROSE_PLUS_RCON_PASSWORD="${WINDROSE_PLUS_RCON_PASSWORD:-}"

# Start the server as steam user
su - steam -w "INVITE_CODE,USE_DIRECT_CONNECTION,SERVER_PORT,DIRECT_CONNECTION_PROXY_ADDRESS,USER_SELECTED_REGION,SERVER_NAME,SERVER_PASSWORD,MAX_PLAYERS,P2P_PROXY_ADDRESS,GENERATE_SETTINGS,UE4SS_ENABLED,WINDROSE_PLUS_ENABLED,WINDROSE_PLUS_VERSION,WINDROSE_PLUS_VERSION_DEFAULT,WINDROSE_PLUS_DASHBOARD_PORT,WINDROSE_PLUS_RCON_PASSWORD,FIRST_BOOT_CONFIG_WAIT_SEC,FIRST_BOOT_WINE_LOG" \
    -c "cd /home/steam/server && ./start.sh" &

killpid="$!"
wait "$killpid"
