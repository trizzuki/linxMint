FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

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

ENV ISO_URL="https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%2010%20Lite%20Edition%2019H2%20x64.iso"

RUN echo '#!/bin/bash
set -e

if [ -e /dev/kvm ]; then
  echo "KVM available"
  KVM_ARG="-enable-kvm"
  CPU_ARG="host"
  MEMORY="4G"
  SMP_CORES=4
else
  echo "KVM not available"
  KVM_ARG=""
  CPU_ARG="qemu64"
  MEMORY="2G"
  SMP_CORES=1
fi

if [ ! -f "/iso/os.iso" ]; then
  wget -q --show-progress "$ISO_URL" -O "/iso/os.iso"
fi

if [ ! -f "/data/disk.qcow2" ]; then
  qemu-img create -f qcow2 "/data/disk.qcow2" 100G
fi

BOOT_ORDER="-boot order=c,menu=on"
if [ ! -s "/data/disk.qcow2" ] || [ $(stat -c%s "/data/disk.qcow2") -lt 1048576 ]; then
  BOOT_ORDER="-boot order=d,menu=on"
fi

qemu-system-x86_64 \
  $KVM_ARG \
  -machine q35,accel=kvm:tcg \
  -cpu $CPU_ARG \
  -m $MEMORY \
  -smp $SMP_CORES \
  -vga std \
  -usb -device usb-tablet \
  $BOOT_ORDER \
  -drive file=/data/disk.qcow2,format=qcow2 \
  -drive file=/iso/os.iso,media=cdrom \
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
  -device e1000,netdev=net0 \
  -display vnc=:0 \
  -name "Windows10_VM" &

sleep 5
websockify --web /novnc 6080 localhost:5900 &

echo "http://localhost:6080"
tail -f /dev/null
' > /start.sh && chmod +x /start.sh

EXPOSE 6080 3389
CMD ["/start.sh"]
