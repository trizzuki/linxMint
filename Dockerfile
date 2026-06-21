FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y \
    lxqt-core \
    openbox \
    pcmanfm-qt \
    qterminal \
    lxqt-panel \
    lxqt-session \
    lxqt-config \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    dbus-x11 \
    x11-xserver-utils \
    xterm \
    sudo \
    wget \
    curl \
    nano \
    net-tools \
    procps \
    locales \
    xfonts-base \
    firefox \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash desktop && \
    echo "desktop:desktop" | chpasswd && \
    usermod -aG sudo desktop

USER desktop
WORKDIR /home/desktop

RUN mkdir -p ~/.vnc

RUN cat > ~/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

xrdb $HOME/.Xresources

export XDG_CURRENT_DESKTOP=LXQt
export DESKTOP_SESSION=LXQt

dbus-launch startlxqt
EOF

RUN chmod +x ~/.vnc/xstartup

RUN printf "desktop\n" | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

USER root

EXPOSE 5901
EXPOSE 6080

CMD bash -c '\
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1; \
su - desktop -c "vncserver :1 -geometry 1366x768 -depth 24"; \
websockify --web=/usr/share/novnc 6080 localhost:5901'
