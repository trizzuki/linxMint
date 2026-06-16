FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ISO_URL="https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%2010%20Lite%20Edition%2019H2%20x64.iso"

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    novnc \
    websockify \
    wget curl net-tools unzip python3 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /iso /novnc

# install noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# ================= START SCRIPT =================
RUN cat <<'EOF' > /start.sh
#!/bin/bash
set -e

echo "=============================="
echo " STARTING WINDOWS QEMU VM"
echo "=============================="

# KVM detect
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

# ISO download
if [ ! -f /iso/os.iso ]; then
  echo "Downloading ISO..."
  wget -O /iso/os.iso "$ISO_URL"
fi

# disk create
if [ ! -f /data/disk.qcow2 ]; then
  echo "Creating disk..."
  qemu-img create -f qcow2 /data/disk.qcow2 40G
fi

echo "Starting QEMU..."

# ================= FIX PENTING =================
# pakai VNC explicit (WAJIB)
qemu-system-x86_64 \
  $KVM \
  -machine q35 \
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
  -vnc 127.0.0.1:0

echo "Waiting VM to boot VNC..."
sleep 5

# FIX websockify mapping (INI YANG SERING SALAH)
websockify --web=/novnc 6080 127.0.0.1:5900 &

echo ""
echo "===================================="
echo " VNC WEB : http://localhost:6080/vnc.html"
echo " VNC RAW : localhost:5900"
echo " RDP     : localhost:3389"
echo "===================================="

tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 6080 5900 3389

CMD ["/start.sh"]
