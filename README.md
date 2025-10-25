PteroVM Builder Egg
===================

Files:
 - install.sh         : installer run by Pterodactyl during server creation
 - vm.sh              : VM manager script (qemu + cloud-init), adapted for env vars
 - egg-pterovm-builder.json : Egg file to import into Pterodactyl

Usage in Pterodactyl:
 - Import egg-pterovm-builder.json into your Panel (Nests -> Eggs -> Import).
 - Create a server using the Egg. In the startup variables set:
    ACTION=create
    VM_NAME=ptero
    OS_CHOICE=1
    RAM=4096
    CPU=2
    DISK=40
    EXTRA=0
    PASSWD=admin123
    START_MODE=--web
 - Start the server in the Panel. The installer will run, then create the VM.
 - To start the VM use ACTION=start and VM_NAME=<name>.

Notes:
 - Containers usually don't provide /dev/kvm; QEMU will run in software-emulation which is slower.
 - If you have a host with KVM available and the container is privileged with /dev/kvm mounted, performance improves greatly.
 - This egg uses sshx.io to provide a web-accessible terminal by default (START_MODE=--web).
