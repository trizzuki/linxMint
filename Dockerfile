FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    cinnamon \
    cinnamon-desktop-environment \
    tigervnc-standalone-server \
    novnc \
    websockify \
    firefox \
    sudo \
    curl \
    wget \
    git \
    vim \
    net-tools \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps \
    xterm \
    tzdata

RUN mkdir -p /root/.vnc

RUN echo '#!/bin/bash' > /root/.vnc/xstartup && \
    echo 'export XKL_XMODMAP_DISABLE=1' >> /root/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> /root/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /root/.vnc/xstartup && \
    echo 'dbus-launch --exit-with-session cinnamon-session &' >> /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

RUN touch /root/.Xauthority

EXPOSE 5901
EXPOSE 6080

CMD bash -c '\
vncserver :1 -geometry 1366x768 -depth 24 -localhost no && \
openssl req -new -x509 -days 365 -nodes \
-subj "/C=ID/ST=JawaTengah/L=Brubahan/O=MintDesktop" \
-out self.pem -keyout self.pem && \
websockify --web=/usr/share/novnc/ \
--cert=self.pem 6080 localhost:5901'
