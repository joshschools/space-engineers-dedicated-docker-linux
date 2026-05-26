#!/bin/bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

CFG=/appdata/space-engineers/SpaceEngineersDedicated/SpaceEngineers-Dedicated.cfg
WORLD=/appdata/space-engineers/World
TMP_CFG=/tmp/SpaceEngineers-Dedicated.cfg

[ -d "$WORLD" ]             || { echo "ERROR: World folder does not exist at $WORLD"; exit 129; }
[ -f "$WORLD/Sandbox.sbc" ] || { echo "ERROR: Sandbox.sbc does not exist in $WORLD"; exit 130; }
[ -f "$CFG" ]               || { echo "ERROR: SpaceEngineers-Dedicated.cfg not found at $CFG"; exit 131; }

sed -E '/.*LoadWorld.*/c\  <LoadWorld>Z:\\appdata\\space-engineers\\World</LoadWorld>' "$CFG" > "$TMP_CFG" \
  && cp "$TMP_CFG" "$CFG" \
  || die "Failed to update LoadWorld in config"

if ls /appdata/space-engineers/Plugins/*.dll &>/dev/null; then
  PLUGINS_STRING=$(ls -1 /appdata/space-engineers/Plugins/*.dll \
    | awk '{ print "<string>" $0 "</string>" }' \
    | tr -d '\n' \
    | awk '{ print "<Plugins>" $0 "</Plugins>" }')
else
  PLUGINS_STRING="<Plugins />"
fi

SED_EXPRESSION_EMPTY="s/<Plugins \/>/${PLUGINS_STRING////\\/} /g"
SED_EXPRESSION_FULL="s/<Plugins>.*<\/Plugins>/${PLUGINS_STRING////\\/} /g"

sed -E "$SED_EXPRESSION_EMPTY" "$CFG" > "$TMP_CFG" && cp "$TMP_CFG" "$CFG" \
  || die "Failed to update empty Plugins element in config"
sed -E "$SED_EXPRESSION_FULL" "$CFG" > "$TMP_CFG" && cp "$TMP_CFG" "$CFG" \
  || die "Failed to update Plugins element in config"

# Set SKIP_UPDATE=1 to skip the steamcmd update step (faster restarts after initial install)
if [ "${SKIP_UPDATE:-0}" != "1" ]; then
  echo "Running steamcmd update for AppID 298740..."
  runuser -l wine bash -c \
    'steamcmd +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +force_install_dir /appdata/space-engineers/SpaceEngineersDedicated +login anonymous +@sSteamCmdForcePlatformType windows +app_update 298740 +quit' \
    || die "steamcmd failed to install/update Space Engineers Dedicated Server"
else
  echo "SKIP_UPDATE=1: skipping steamcmd update"
fi

runuser -l wine bash -c '/entrypoint-space_engineers.bash' \
  || die "Space Engineers server process exited with error"
