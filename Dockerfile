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

RUN printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
    > /etc/apt/preferences.d/mozilla-firefox

RUN echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' \
    > /etc/apt/apt.conf.d/51unattended-upgrades-firefox

RUN apt update -y && apt install -y firefox \
    && rm -rf /var/lib/apt/lists/*

# Setup direktori VNC
RUN mkdir -p /root/.vnc

# Buat VNC password file secara non-interaktif (tanpa TTY)
RUN printf '12345678\n12345678\nn\n' | vncpasswd /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# xstartup untuk Cinnamon
RUN printf '#!/bin/bash\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexport XKL_XMODMAP_DISABLE=1\n[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources\ndbus-launch --exit-with-session cinnamon-session &\n' \
    > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

RUN touch /root/.Xauthority

# Tulis entrypoint langsung ke image (tidak perlu COPY)
RUN printf '#!/bin/bash\nset -e\n\n\
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1\n\n\
openssl req -new -subj "/C=JP/CN=novnc" \\\n\
    -x509 -days 365 -nodes \\\n\
    -out /root/self.pem -keyout /root/self.pem\n\n\
vncserver :1 \\\n\
    -localhost no \\\n\
    -SecurityTypes VncAuth \\\n\
    -geometry 1280x768 \\\n\
    -depth 24\n\n\
websockify -D \\\n\
    --web=/usr/share/novnc/ \\\n\
    --cert=/root/self.pem \\\n\
    0.0.0.0:6080 \\\n\
    localhost:5901\n\n\
tail -f /dev/null\n' \
    > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 5901
EXPOSE 6080

CMD ["/entrypoint.sh"]
