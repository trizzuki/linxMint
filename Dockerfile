FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ===== Install dependencies =====
RUN apt-get update && apt-get install -y \
    qemu-system-x86 \
    qemu-utils \
    novnc \
    websockify \
    wget \
    curl \
    net-tools \
    unzip \
    python3 \
    procps \
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===== Directories (NO VOLUME in Dockerfile!) =====
RUN mkdir -p /data /iso /novnc

# ===== noVNC =====
RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# ===== ISO =====
ENV ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195280&clcid=0x409&culture=en-us&country=US"

# ===== Start Script =====
RUN printf '#!/bin/bash\n\
set -e\n\
\n\
echo "===== QEMU + noVNC STARTING ====="\n\
\n\
# ===== Storage check (Railway Volume mount goes here) =====\n\
mkdir -p /data /iso\n\
\n\
# ===== KVM detection =====\n\
if [ -e /dev/kvm ]; then\n\
  echo "KVM enabled"\n\
  KVM=\"-enable-kvm\"\n\
  CPU=\"host\"\n\
  RAM=\"2G\"\n\
  CORES=2\n\
else\n\
  echo "KVM not available"\n\
  KVM=\"\"\n\
  CPU=\"qemu64\"\n\
  RAM=\"2G\"\n\
  CORES=2\n\
fi\n\
\n\
# ===== Download ISO =====\n\
if [ ! -f /iso/os.iso ]; then\n\
  echo "Downloading ISO..."\n\
  wget -q "$ISO_URL" -O /iso/os.iso || echo "ISO download failed"\n\
fi\n\
\n\
# ===== Disk (PERSISTENT via Railway Volume /data) =====\n\
if [ ! -f /data/disk.qcow2 ]; then\n\
  echo "Creating disk..."\n\
  qemu-img create -f qcow2 /data/disk.qcow2 32G\n\
fi\n\
\n\
# ===== Boot mode =====\n\
BOOT=\"-boot order=c\"\n\
if [ ! -s /data/disk.qcow2 ]; then\n\
  BOOT=\"-boot order=d\"\n\
fi\n\
\n\
echo "Starting QEMU..."\n\
\n\
qemu-system-x86_64 \\\n\
  $KVM \\\n\
  -machine q35 \\\n\
  -cpu $CPU \\\n\
  -m $RAM \\\n\
  -smp $CORES \\\n\
  -vga std \\\n\
  -usb -device usb-tablet \\\n\
  $BOOT \\\n\
  -drive file=/data/disk.qcow2,format=qcow2 \\\n\
  -drive file=/iso/os.iso,media=cdrom \\\n\
  -netdev user,id=net0 \\\n\
  -device e1000,netdev=net0 \\\n\
  -vnc 0.0.0.0:0 \\\n\
  -name "QEMU_VM" &\n\
\n\
sleep 5\n\
echo "Starting noVNC..."\n\
\n\
websockify --web=/novnc 6080 localhost:5900 &\n\
\n\
echo "================================"\n\
echo "Open: http://localhost:6080"\n\
echo "================================"\n\
\n\
tail -f /dev/null\n' > /start.sh && chmod +x /start.sh

EXPOSE 6080 3389

CMD ["/start.sh"]
