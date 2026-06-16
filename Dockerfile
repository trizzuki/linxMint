FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y \
    ubuntu-desktop-minimal \
    gnome-session \
    gnome-terminal \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    firefox \
    dbus-x11 \
    x11-xserver-utils \
    xterm \
    sudo \
    wget \
    curl \
    net-tools \
    procps \
    nano \
    locales \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash desktop && \
    echo "desktop:desktop" | chpasswd && \
    adduser desktop sudo

USER desktop
WORKDIR /home/desktop

RUN mkdir -p ~/.vnc

# 🔥 GNOME xstartup FIXED
RUN cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash

export XKL_XMODMAP_DISABLE=1
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export DESKTOP_SESSION=ubuntu

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

exec dbus-run-session gnome-session
EOF

RUN chmod +x ~/.vnc/xstartup

# VNC password benar (stabil method)
RUN printf 'desktop\n' | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

USER root

EXPOSE 5901
EXPOSE 6080

# 🔥 FIX: tambah delay + safety wait
CMD bash -c '\
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1; \
su - desktop -c "vncserver :1 -localhost no -geometry 1280x720 -depth 24"; \
sleep 3; \
until ss -tln | grep 5901; do echo "waiting vnc..."; sleep 1; done; \
websockify --web=/usr/share/novnc 6080 localhost:5901'
