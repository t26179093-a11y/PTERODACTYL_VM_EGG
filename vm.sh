#!/bin/bash
# All-in-One VM Manager (QEMU + Cloud-Init) - adapted for Pterodactyl Egg
# Supports non-interactive use via environment variables:
# VM_NAME, OS_CHOICE (1-5), RAM, CPU, DISK, EXTRA, PASSWD, START_MODE (--web or empty)
BASE_DIR="/home/container/vms"
mkdir -p "$BASE_DIR"

ensure_tools() {
  for cmd in qemu-system-x86_64 qemu-img cloud-localds wget; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Fehler: $cmd ist nicht installiert."
      exit 1
    fi
  done
}

create_vm_noninteractive() {
  VM_NAME="${VM_NAME:-ptero}"
  VM_DIR="$BASE_DIR/$VM_NAME"
  mkdir -p "$VM_DIR"

  OS_CHOICE="${OS_CHOICE:-1}"
  case $OS_CHOICE in
    1) IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img" ;;
    2) IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" ;;
    3) IMG_URL="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2" ;;
    4) IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2" ;;
    5) IMG_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2" ;;
    *) echo "Ungültige OS_CHOICE"; exit 1 ;;
  esac

  RAM="${RAM:-2048}"
  CPU="${CPU:-2}"
  DISK="${DISK:-20}"
  EXTRA="${EXTRA:-0}"
  PASSWD="${PASSWD:-test123}"

  echo "Lade OS-Image herunter..."
  wget -q --show-progress -O "$VM_DIR/$VM_NAME.img" "$IMG_URL"

  echo "Erweitere Image auf ${DISK}G ..."
  qemu-img resize "$VM_DIR/$VM_NAME.img" ${DISK}G

  echo "Erstelle Cloud-Init Konfiguration..."
  cat > "$VM_DIR/user-data" <<EOF
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

  echo "instance-id: iid-$VM_NAME" > "$VM_DIR/meta-data"

  cloud-localds "$VM_DIR/seed.img" "$VM_DIR/user-data" "$VM_DIR/meta-data"

  if [ "$EXTRA" -gt 0 ]; then
    echo "Erstelle extra.img (${EXTRA}G)..."
    qemu-img create -f qcow2 "$VM_DIR/extra.img" ${EXTRA}G
  fi

  echo "RAM=$RAM" > "$VM_DIR/config.txt"
  echo "CPU=$CPU" >> "$VM_DIR/config.txt"

  echo "✅ VM '$VM_NAME' erstellt in $VM_DIR."
  echo "Starte mit: ./vm.sh start $VM_NAME"
}

start_vm_noninteractive() {
  VM_NAME="$1"
  VM_DIR="$BASE_DIR/$VM_NAME"

  if [ ! -d "$VM_DIR" ]; then
    echo "❌ VM '$VM_NAME' existiert nicht."
    exit 1
  fi

  RAM=$(grep RAM "$VM_DIR/config.txt" | cut -d= -f2)
  CPU=$(grep CPU "$VM_DIR/config.txt" | cut -d= -f2)
  IMG_FILE="$VM_DIR/$VM_NAME.img"
  SEED_FILE="$VM_DIR/seed.img"
  EXTRA_FILE="$VM_DIR/extra.img"

  if [ -e /dev/kvm ]; then
    KVM_OPT="-enable-kvm"
  else
    echo "⚠️ KVM nicht verfügbar - läuft software-emuliert."
    KVM_OPT=""
  fi

  echo "Starte VM '$VM_NAME' mit $CPU CPU(s), $RAM MB RAM ..."

  CMD="qemu-system-x86_64 \
    -m $RAM \
    -smp $CPU \
    $KVM_OPT \
    -drive file=$IMG_FILE,if=virtio,format=raw,cache=writeback,aio=threads \
    -drive file=$SEED_FILE,if=virtio,format=raw \
    $( [ -f $EXTRA_FILE ] && echo \"-drive file=$EXTRA_FILE,if=virtio,format=qcow2\" ) \
    -boot c \
    -nographic \
    -serial mon:stdio"

  if [ "${START_MODE:---web}" == "--web" ]; then
    echo "🌐 Starte sshx.io Web-Terminal..."
    curl -fsSL https://sshx.io/get | sh -s -- bash -c \"$CMD\"
  else
    echo "💻 Interaktiver Modus – (STRG + A dann X zum Beenden)"
    eval "$CMD"
  fi
}

# Interactive original functions (kept for fallback)
BASE_DIR_ORIG="/root/vms"

create_vm_interactive() {
  # original interactive create function kept minimal for fallback
  echo "Interactive create not recommended in container. Use environment variables."
  create_vm_noninteractive
}

start_vm_interactive() {
  echo "Interactive start not supported here. Use start VM_NAME"
  start_vm_noninteractive "$1"
}

stop_vm() {
  VM_NAME="$1"
  PID_FILE="$BASE_DIR/$VM_NAME/vm.pid"
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")"
    rm -f "$PID_FILE"
    echo "🛑 VM '$VM_NAME' gestoppt."
  else
    echo "❌ Keine laufende VM gefunden."
  fi
}

delete_vm() {
  VM_NAME="$1"
  read -p "⚠️ VM '$VM_NAME' wirklich löschen? (y/N): " CONFIRM
  if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
    rm -rf "$BASE_DIR/$VM_NAME"
    echo "🗑️ VM '$VM_NAME' gelöscht."
  else
    echo "Abgebrochen."
  fi
}

list_vms() {
  echo "📦 Verfügbare VMs:"
  ls "$BASE_DIR"
}

case "$1" in
  create)
    ensure_tools
    create_vm_noninteractive
    ;;
  start)
    ensure_tools
    if [ -z "$2" ]; then
      echo "Usage: ./vm.sh start VM_NAME"
      exit 1
    fi
    start_vm_noninteractive "$2"
    ;;
  stop) stop_vm "$2" ;;
  delete) delete_vm "$2" ;;
  list) list_vms ;;
  *) echo "Verwendung: ./vm.sh {create|start|stop|delete|list}" ;;
esac
