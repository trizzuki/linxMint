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

RUN wget -q https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# ===== START SCRIPT =====
RUN cat <<'EOF' > /start.sh
#!/bin/bash
set -e

echo "=============================="
echo " QEMU WINDOWS VM STARTING"
echo "=============================="

# Detect KVM
if [ -e /dev/kvm ]; then
  echo "KVM ENABLED"
  KVM="-enable-kvm"
  CPU="host"
  RAM="4G"
  SMP="4"
else
  echo "KVM NOT AVAILABLE"
  KVM=""
  CPU="qemu64"
  RAM="2G"
  SMP="1"
fi

# Download ISO
if [ ! -f /iso/os.iso ]; then
  echo "Downloading ISO..."
  wget -O /iso/os.iso "$ISO_URL"
fi

# Create disk
if [ ! -f /data/disk.qcow2 ]; then
  echo "Creating disk..."
  qemu-img create -f qcow2 /data/disk.qcow2 40G
fi

echo "Starting QEMU..."

qemu-system-x86_64 \
  $KVM \
  -machine q35,accel=kvm:tcg \
  -cpu $CPU \
  -m $RAM \
  -smp $SMP \
  -vga std \
  -usb -device usb-tablet \
  -drive file=/data/disk.qcow2,format=qcow2 \
  -drive file=/iso/os.iso,media=cdrom \
  -boot order=d \
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
  -device e1000,netdev=net0 \
  -vnc :0 \
  -daemonize

echo "Starting noVNC..."

websockify --web=/novnc 6080 localhost:5900 &

echo ""
echo "===================================="
echo " VNC  : localhost:5900"
echo " WEB  : http://localhost:6080/vnc.html"
echo " RDP  : localhost:3389"
echo "===================================="

tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 6080 5900 3389

CMD ["/start.sh"]
