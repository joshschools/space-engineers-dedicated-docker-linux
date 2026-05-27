FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    WINEARCH=win64 \
    WINEPREFIX=/wineprefix

# Add i386 arch + WineHQ stable repo, then install Wine + headless deps
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates wget gnupg2 \
        xvfb cabextract unzip curl lib32gcc-s1 xz-utils \
 && mkdir -pm755 /etc/apt/keyrings \
 && wget -O /etc/apt/keyrings/winehq-archive.key \
        https://dl.winehq.org/wine-builds/winehq.key \
 && wget -NP /etc/apt/sources.list.d/ \
        https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources \
 && apt-get update \
 && apt-get install -y --install-recommends winehq-stable \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Install latest winetricks directly from upstream (distro package is always stale)
RUN wget -q -O /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
 && chmod +x /usr/local/bin/winetricks

# Ubuntu 24.04 base ships an 'ubuntu' user at UID 1000 — rename it to 'wine'
# rather than creating a new one; UID 1000 must match the chown in the start script
RUN usermod -l wine -d /home/wine -m ubuntu \
 && groupmod -n wine ubuntu

# Install SteamCMD under the wine user; symlink to PATH
RUN mkdir -p /home/wine/steamcmd \
 && curl -sqL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    | tar xz -C /home/wine/steamcmd \
 && chown -R wine:wine /home/wine/steamcmd \
 && printf '#!/bin/bash\ncd /home/wine/steamcmd\nexec ./steamcmd.sh "$@"\n' > /usr/local/bin/steamcmd \
 && chmod +x /usr/local/bin/steamcmd

# Set up Wine prefix and appdata skeleton
RUN mkdir -p /wineprefix /appdata/space-engineers/bins /appdata/space-engineers/config \
 && chown -R wine:wine /wineprefix /appdata

# Pre-create XDG_RUNTIME_DIR and X11 socket dir as root so wine user can use them
RUN mkdir -p /run/user/1000 /tmp/.X11-unix \
 && chown wine:wine /run/user/1000 \
 && chmod 700 /run/user/1000 \
 && chmod 1777 /tmp/.X11-unix

# Download wine-mono MSI as root (wine user cannot write /usr/share/wine/mono/)
RUN mkdir -p /usr/share/wine/mono \
 && MSCOREE=$(find /usr/lib/wine -name 'mscoree.so' 2>/dev/null | head -1) \
 && MONO_VER=$([ -n "$MSCOREE" ] && grep -ao 'wine-mono-[0-9.]*' "$MSCOREE" 2>/dev/null | head -1 | sed 's/wine-mono-//' || echo '') \
 && [ -n "$MONO_VER" ] || MONO_VER=9.4.0 \
 && echo "Downloading wine-mono ${MONO_VER}..." \
 && wget -q -O "/usr/share/wine/mono/wine-mono-${MONO_VER}-x86.msi" \
         "https://dl.winehq.org/wine/wine-mono/${MONO_VER}/wine-mono-${MONO_VER}-x86.msi" \
 && echo "wine-mono ${MONO_VER} ready"

COPY install-winetricks /scripts/install-winetricks
RUN chmod +x /scripts/install-winetricks \
 && chown wine:wine /scripts/install-winetricks

WORKDIR /scripts
RUN runuser -l wine bash -c /scripts/install-winetricks

COPY entrypoint.bash /entrypoint.bash
COPY entrypoint-space_engineers.bash /entrypoint-space_engineers.bash
RUN chmod +x /entrypoint.bash /entrypoint-space_engineers.bash

CMD ["/entrypoint.bash"]
