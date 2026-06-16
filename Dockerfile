FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# VM defaults

ENV VM_RAM=16384
ENV VM_CPUS=4
ENV DISK_SIZE=200G
ENV PORT=6080

# Windows ISO URL (override if desired)

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
    
RUN mkdir -p /data /iso

# Latest noVNC + websockify

RUN git clone --depth=1 https://github.com/novnc/noVNC.git /novnc && 
git clone --depth=1 https://github.com/novnc/websockify.git /opt/websockify

RUN cat << 'EOF' > /start.sh
#!/bin/bash
set -e

echo "========================================="
echo "Starting Universal Windows VM"
echo "========================================="

# --------------------------------------------------

# KVM Detection

# --------------------------------------------------

KVM_ENABLED=false

if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
KVM_ENABLED=true
fi

if [ "$KVM_ENABLED" = true ]; then
echo "KVM detected"

```
ACCEL="-accel kvm"
CPU="-cpu host"
```

else
echo "KVM unavailable -> TCG mode"

```
ACCEL="-accel tcg,thread=multi"
CPU="-cpu max"
```

fi

# --------------------------------------------------

# Resource Detection

# --------------------------------------------------

HOST_RAM=$(free -m | awk '/Mem:/ {print $2}')
HOST_CPUS=$(nproc)

TARGET_RAM=${VM_RAM:-16384}

if [ "$HOST_RAM" -lt "$TARGET_RAM" ]; then
TARGET_RAM=$((HOST_RAM * 75 / 100))
fi

TARGET_CPUS=${VM_CPUS:-4}

if [ "$TARGET_CPUS" -gt "$HOST_CPUS" ]; then
TARGET_CPUS=$HOST_CPUS
fi

echo "VM RAM  : ${TARGET_RAM} MB"
echo "VM CPUs : ${TARGET_CPUS}"

# --------------------------------------------------

# ISO Download

# --------------------------------------------------

if [ ! -f /iso/os.iso ]; then
echo "Downloading ISO..."
wget -O /iso/os.iso "$ISO_URL"
fi

# --------------------------------------------------

# Disk Creation

# --------------------------------------------------

if [ ! -f /data/disk.qcow2 ]; then
echo "Creating ${DISK_SIZE} disk..."
qemu-img create -f qcow2 /data/disk.qcow2 ${DISK_SIZE}
fi

# --------------------------------------------------

# Boot Logic

# --------------------------------------------------

BOOT_ORDER="c"

if [ ! -f /data/.installed ]; then
BOOT_ORDER="d"
fi

# --------------------------------------------------

# Start VM

# --------------------------------------------------

qemu-system-x86_64 
$ACCEL 
$CPU 
-machine type=q35 
-m ${TARGET_RAM}M 
-smp ${TARGET_CPUS} 
-vga std 
-usb 
-device usb-tablet 
-boot order=${BOOT_ORDER},menu=on 
-drive file=/data/disk.qcow2,format=qcow2 
-drive file=/iso/os.iso,media=cdrom 
-netdev user,id=net0,hostfwd=tcp::3389-:3389 
-device e1000,netdev=net0 
-display vnc=:0 
-name Windows_VM &

VM_PID=$!

sleep 5

python3 /opt/websockify/run 
0.0.0.0:${PORT} 
--web /novnc 
localhost:5900 &

echo ""
echo "========================================="
echo "VM READY"
echo "========================================="
echo "noVNC : Port ${PORT}"
echo "RDP   : Port 3389"
echo "========================================="

wait $VM_PID
EOF

RUN chmod +x /start.sh

EXPOSE 6080
EXPOSE 3389

CMD ["/start.sh"]
