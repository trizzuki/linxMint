FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ISO_URL="https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%2010%20Lite%20Edition%2019H2%20x64.iso"

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    novnc \
    websockify \
    wget \
    curl \
    net-tools \
    unzip \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /iso /novnc

RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master


RUN cat <<'EOF' > /start.sh
#!/bin/bash
set -e

echo "Starting VM..."

# FORCE TCG (lebih stabil di Railway)
KVM_ARG=""
CPU_ARG="qemu64"
MEMORY="2G"
SMP_CORES=1

# ISO
if [ ! -f "/iso/os.iso" ]; then
  echo "Downloading ISO..."
  wget -q --show-progress "$ISO_URL" -O "/iso/os.iso"
fi

# Disk
if [ ! -f "/data/disk.qcow2" ]; then
  echo "Creating disk..."
  qemu-img create -f qcow2 "/data/disk.qcow2" 40G
fi

echo "Starting QEMU..."

qemu-system-x86_64 \
  -machine q35,accel=tcg \
  -cpu $CPU_ARG \
  -m $MEMORY \
  -smp $SMP_CORES \
  -vga std \
  -usb -device usb-tablet \
  -vnc :0 \
  -drive file=/data/disk.qcow2,format=qcow2 \
  -drive file=/iso/os.iso,media=cdrom \
  -netdev user,id=net0 \
  -device e1000,netdev=net0 &

echo "Starting noVNC..."

websockify --web=/novnc 0.0.0.0:6080 localhost:5900 --ssl-only=false &

echo "================================"
echo "VNC: http://localhost:6080"
echo "================================"

tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 6080

CMD ["/start.sh"]
