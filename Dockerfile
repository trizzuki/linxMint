FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=root
ENV HOME=/root

RUN apt update -y && apt install --no-install-recommends -y \
    cinnamon \
    cinnamon-desktop-environment \
    tigervnc-standalone-server \
    novnc \
    websockify \
    sudo \
    xterm \
    vim \
    net-tools \
    curl \
    wget \
    git \
    tzdata \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps \
    software-properties-common \
    openssl \
    && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository ppa:mozillateam/ppa -y

RUN echo 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001' \
    > /etc/apt/preferences.d/mozilla-firefox

RUN echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' \
    > /etc/apt/apt.conf.d/51unattended-upgrades-firefox

RUN apt update -y && apt install -y firefox \
    && rm -rf /var/lib/apt/lists/*

# Setup VNC — pakai passwd file agar tidak perlu TTY
RUN mkdir -p /root/.vnc

# Buat VNC password file secara non-interaktif (8 char minimum)
RUN printf '12345678\n12345678\nn\n' | vncpasswd /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# xstartup untuk Cinnamon
RUN echo '#!/bin/bash\n\
unset SESSION_MANAGER\n\
unset DBUS_SESSION_BUS_ADDRESS\n\
export XKL_XMODMAP_DISABLE=1\n\
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup\n\
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources\n\
dbus-launch --exit-with-session cinnamon-session &' \
    > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

RUN touch /root/.Xauthority

EXPOSE 5901
EXPOSE 6080

# Gunakan script entrypoint terpisah agar lebih robust
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
