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
 && ln -s /home/wine/steamcmd/steamcmd.sh /usr/local/bin/steamcmd

# Set up Wine prefix and appdata skeleton
RUN mkdir -p /wineprefix /appdata/space-engineers/bins /appdata/space-engineers/config \
 && chown -R wine:wine /wineprefix /appdata

COPY install-winetricks /scripts/install-winetricks
RUN chmod +x /scripts/install-winetricks \
 && chown wine:wine /scripts/install-winetricks

WORKDIR /scripts
RUN runuser -l wine bash -c /scripts/install-winetricks

COPY entrypoint.bash /entrypoint.bash
COPY entrypoint-space_engineers.bash /entrypoint-space_engineers.bash
RUN chmod +x /entrypoint.bash /entrypoint-space_engineers.bash

CMD ["/entrypoint.bash"]
