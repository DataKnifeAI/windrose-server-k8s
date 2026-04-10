#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

SERVER_FILES="/home/steam/server-files"

cd "$SERVER_FILES" || exit

LogAction "Starting Windrose Dedicated Server"

EXEC="$SERVER_FILES/WindroseServer.exe"

if [ ! -f "$EXEC" ]; then
    LogError "Could not find server executable at: $EXEC"
    exit 1
fi

export WINEPREFIX="${HOME}/.wine"
export WINEARCH=win64
export WINEDEBUG=-all

LogInfo "Server is starting..."

exec wine "$EXEC" -log
