FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1

RUN apt-get update && apt-get install -y \
    cinnamon-desktop-environment \
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash desktop && \
    echo "desktop:desktop" | chpasswd && \
    adduser desktop sudo

USER desktop
WORKDIR /home/desktop

RUN mkdir -p ~/.vnc

RUN printf '#!/bin/bash\n\
xrdb $HOME/.Xresources\n\
export XKL_XMODMAP_DISABLE=1\n\
dbus-launch --exit-with-session cinnamon-session\n' \
> ~/.vnc/xstartup && \
chmod +x ~/.vnc/xstartup

RUN printf 'desktop\n' | vncpasswd -f > ~/.vnc/passwd && \
chmod 600 ~/.vnc/passwd

USER root

EXPOSE 5901
EXPOSE 6080

CMD bash -c '\
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1; \
su - desktop -c "vncserver :1 -geometry 1280x720 -depth 24"; \
websockify --web=/usr/share/novnc 6080 localhost:5901'
