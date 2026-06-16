FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# =========================
# VM DEFAULTS (Railway-safe)
# =========================
ENV VM_RAM=2048
ENV VM_CPUS=2
ENV DISK_SIZE=40G
ENV PORT=6080

ENV ISO_URL="https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%2010%20Lite%20Edition%2019H2%20x64.iso"

# =========================
# INSTALL DEPENDENCIES
# =========================
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
    git \
    procps \
    && rm -rf /var/lib/apt/lists/*

# =========================
# DIRECTORIES (FIX REQUESTED)
# =========================
RUN mkdir -p /data /iso /novnc

# =========================
# NOVNC + WEBSOCKIFY
# =========================
RUN git clone --depth=1 https://github.com/novnc/noVNC.git /novnc && \
    git clone --depth=1 https://github.com/novnc/websockify.git /opt/websockify

# =========================
# START SCRIPT
# =========================
RUN cat << 'EOF' > /start.sh
#!/bin/bash
set -e

echo "========================================="
echo " QEMU WINDOWS VM STARTING"
echo "========================================="

# =========================
# ENSURE STORAGE EXISTS
# =========================
mkdir -p /data /iso

# =========================
# KVM DETECTION
# =========================
if [ -e /dev/kvm ]; then
    echo "KVM detected"
    ACCEL="-enable-kvm"
    CPU="-cpu host"
else
    echo "KVM not available (TCG mode)"
    ACCEL=""
    CPU="-cpu qemu64"
fi

# =========================
# SAFE RESOURCE LIMIT
# =========================
HOST_RAM=$(free -m | awk '/Mem:/ {print $2}')
TARGET_RAM=${VM_RAM:-2048}

if [ "$HOST_RAM" -lt "$TARGET_RAM" ]; then
    TARGET_RAM=$((HOST_RAM * 70 / 100))
fi

TARGET_CPUS=${VM_CPUS:-2}
HOST_CPUS=$(nproc)

if [ "$TARGET_CPUS" -gt "$HOST_CPUS" ]; then
    TARGET_CPUS=$HOST_CPUS
fi

echo "RAM  : ${TARGET_RAM} MB"
echo "CPU  : ${TARGET_CPUS}"

# =========================
# ISO DOWNLOAD
# =========================
if [ ! -f /iso/os.iso ]; then
    echo "Downloading ISO..."
    wget -O /iso/os.iso "$ISO_URL" || echo "ISO download failed"
fi

# =========================
# DISK CREATION
# =========================
if [ ! -f /data/disk.qcow2 ]; then
    echo "Creating disk..."
    qemu-img create -f qcow2 /data/disk.qcow2 ${DISK_SIZE}
fi

# =========================
# BOOT MODE
# =========================
BOOT="c"
if [ ! -f /data/.installed ]; then
    BOOT="d"
fi

# =========================
# START QEMU (FIXED)
# =========================
qemu-system-x86_64 \
    $ACCEL \
    $CPU \
    -machine q35 \
    -m ${TARGET_RAM}M \
    -smp ${TARGET_CPUS} \
    -vga std \
    -usb -device usb-tablet \
    -boot order=${BOOT},menu=on \
    -drive file=/data/disk.qcow2,format=qcow2 \
    -drive file=/iso/os.iso,media=cdrom \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
    -device e1000,netdev=net0 \
    -vnc 0.0.0.0:0 \
    -name Windows_VM &

VM_PID=$!

sleep 10

echo "Starting noVNC..."

python3 /opt/websockify/run \
    0.0.0.0:${PORT} \
    --web /novnc \
    localhost:5900 &

echo "========================================="
echo " VM READY"
echo "========================================="
echo "noVNC : http://0.0.0.0:${PORT}"
echo "RDP   : localhost:3389"
echo "========================================="

wait $VM_PID
EOF

RUN chmod +x /start.sh

# =========================
# PORTS
# =========================
EXPOSE 6080
EXPOSE 3389

CMD ["/start.sh"]
