# Sourced by start/stop/restart. Uses sudo only when docker is not available to the current user.
if docker compose version &>/dev/null 2>&1; then
  SUDO=()
else
  SUDO=(sudo)
fi

docker_compose() {
  "${SUDO[@]}" docker compose "$@"
}
