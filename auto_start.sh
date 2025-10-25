#!/bin/bash
# Auto Start Script für PteroVM im Container

cd /home/container || exit 1

VM_NAME="${VM_NAME:-ptero-vm}"
OS_CHOICE="${OS_TYPE:-2}"          # 1=Ubuntu22.04, 2=Ubuntu24.04, 3=Debian11, 4=Debian12, 5=Debian13
RAM="${VM_RAM:-4096}"
CPU="${VM_CPU:-2}"
DISK="${VM_DISK:-20}"
EXTRA="0"
PASSWD="${ROOT_PASS:-test123}"
START_MODE="--web"

# Prüfen ob QEMU installiert ist
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "🧠 QEMU nicht gefunden. Installiere QEMU..."
    apt update -y
    DEBIAN_FRONTEND=noninteractive apt install -y qemu-system-x86 qemu-utils cloud-image-utils wget curl
fi

BASE_DIR="/root/vms"
mkdir -p "$BASE_DIR/$VM_NAME"

if [ ! -f "$BASE_DIR/$VM_NAME/$VM_NAME.img" ]; then
    echo "🧠 Erstelle neue VM $VM_NAME..."

    case "$OS_CHOICE" in
        1) IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img" ;;
        2) IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" ;;
        3) IMG_URL="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2" ;;
        4) IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2" ;;
        5) IMG_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2" ;;
        *) IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" ;;
    esac

    echo "📥 Lade OS Image..."
    wget -O "$BASE_DIR/$VM_NAME/$VM_NAME.img" "$IMG_URL"

    echo "💾 Erweitere Disk auf ${DISK}G..."
    qemu-img resize "$BASE_DIR/$VM_NAME/$VM_NAME.img" ${DISK}G

    echo "🔐 Erstelle Cloud-Init Konfiguration..."
    cat > "$BASE_DIR/$VM_NAME/user-data" <<EOF
#cloud-config
hostname: $VM_NAME
manage_etc_hosts: true
users:
  - name: root
    lock_passwd: false
    plain_text_passwd: '$PASSWD'
    shell: /bin/bash
ssh_pwauth: true
chpasswd:
  list: |
     root:$PASSWD
  expire: False
EOF

    echo "instance-id: iid-$VM_NAME" > "$BASE_DIR/$VM_NAME/meta-data"
    cloud-localds "$BASE_DIR/$VM_NAME/seed.img" "$BASE_DIR/$VM_NAME/user-data" "$BASE_DIR/$VM_NAME/meta-data"
fi

echo "🚀 Starte VM $VM_NAME..."
CMD="qemu-system-x86_64 -m $RAM -smp $CPU -enable-kvm \
-drive file=$BASE_DIR/$VM_NAME/$VM_NAME.img,if=virtio,format=raw,cache=writeback,aio=threads \
-drive file=$BASE_DIR/$VM_NAME/seed.img,if=virtio,format=raw \
-boot c -nographic -serial mon:stdio"

eval "$CMD"
