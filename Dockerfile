FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y \
    ubuntu-mate-desktop \
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
    usermod -aG sudo desktop

USER desktop
WORKDIR /home/desktop

RUN mkdir -p /home/desktop/.vnc

RUN cat > /home/desktop/.vnc/xstartup << 'EOF'
#!/bin/bash

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export XDG_CURRENT_DESKTOP=MATE
export DESKTOP_SESSION=mate
export XKL_XMODMAP_DISABLE=1

dbus-launch --exit-with-session mate-session
EOF

RUN chmod +x /home/desktop/.vnc/xstartup

RUN printf 'desktop\n' | vncpasswd -f > /home/desktop/.vnc/passwd && \
    chmod 600 /home/desktop/.vnc/passwd

USER root

EXPOSE 5901
EXPOSE 6080

CMD bash -c '\
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1; \
su - desktop -c "vncserver :1 \
-localhost no \
-SecurityTypes None \
-geometry 1280x720 \
-depth 24"; \
websockify --web=/usr/share/novnc 6080 localhost:5901'
