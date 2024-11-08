#!/bin/sh
#/boot/vmlinuz-lts modules=loop,squashfs,sd-mod,usb-storage nomodeset console=ttyS0,115200 initrd=/boot/initramfs-lts
set -ex

XUSER=sysres
HOST=alpine-docker
KEYMAP="fr fr"
TIMEZONE="Europe/Paris"
FS=ext4
FEATURES="ata base ide scsi usb virtio $FS network"
MODULES="sd-mod,usb-storage,$FS"
MIRROR=http://mirrors.ircam.fr/pub/alpine
IFACE=eth2
TARGET_DEV=/dev/sda

_RELEASE=$(awk -F. -v OFS=. '{print $1,$2}' /etc/alpine-release)
_ARCH=$(uname -m)
_REPO_MAIN=$MIRROR/v$_RELEASE/main
_REPO_COMMUNITY=$MIRROR/v$_RELEASE/community

_ROOT=/mnt/root
_BOOT=/mnt/boot

_exit_with_msg() {
  echo "$1"
  exit 111
}

make_dir() {
    OWNER="$1"
    PERMS="$2"
    DIR="$3"
    mkdir -p "$DIR"
    chown "$OWNER" "$DIR"
    chmod "$PERMS" "$DIR"
}

make_file() {
    OWNER="$1"
    PERMS="$2"
    FILENAME="$3"
    cat > "$FILENAME"
    chown "$OWNER" "$FILENAME"
    chmod "$PERMS" "$FILENAME"
}

check_env() {
  [ "$(id -u)" -eq "0" ] || _exit_with_msg "You need to run this as root"
  [ -f /etc/apk/world ] || _exit_with_msg "You should be running this from alpine"
}

check_network() {
  nc -zw1 8.8.8.8 443 || {
    ifconfig $IFACE up
    busybox udhcpc -i $IFACE
  }
}

mount_partitions() {
  mkdir -p $_ROOT
  mkdir -p $_BOOT
  mount "${TARGET_DEV}3" $_ROOT
  mount "${TARGET_DEV}1" $_BOOT
  mount --bind /proc $_ROOT/proc
  mount --bind /dev $_ROOT/dev
  mount --bind /sys $_ROOT/sys
}
umount_partitions() {
  sync
  umount $_ROOT/proc
  umount $_ROOT/dev
  umount $_ROOT/sys
  umount $_ROOT
  umount $_BOOT
}

set_answer_file() {
  echo "
        KEYMAPOPTS=\"$KEYMAP\"
        HOSTNAMEOPTS=$HOST
        USEROPTS=\"-u -g $XUSER $XUSER\"
        TIMEZONEOPTS=$TIMEZONE
        SSHDOPTS=openssh
        NTPOPTS=chrony
        APKREPOSOPTS=\"-f -c\"

        INTERFACESOPTS=none
        PROXYOPTS=none
        LBUOPTS=none
        APKCACHEOPTS=none

        # Use /dev/sda as a system disk
        DISKOPTS=\"-m sys $TARGET_DEV\"
        " | sed 's/^ *//' >"$1"
}

call_setup_alpine() {
  answer_file=/tmp/answers.txt
  set_answer_file $answer_file
  cat $answer_file
  /sbin/setup-alpine -f $answer_file -e
}

configure_apu_console() {
  sed -i \
    -e '1i SERIAL 0 115200' \
    -e 's/quiet/console=ttyS0,115200/' \
    $_BOOT/extlinux.conf
  sed -i \
    -e 's/^serial_port.*/serial_port=0/' \
    -e 's/^serial_baud.*/serial_baud=115200/' \
    -e 's/ quiet / console=ttyS0,115200 /' \
    $_ROOT/etc/update-extlinux.conf
  sync
}

setup_network() {
  cat /etc/resolv.conf >$_ROOT/etc/resolv.conf
  echo "
    auto lo
    iface lo inet loopback
    auto $IFACE
    iface $IFACE inet dhcp
    " | sed 's/^ *//' >$_ROOT/etc/network/interfaces
}

setup_apk_repository() {
  alpine_release=$(awk -F. -v OFS=. '{print $1,$2}' /etc/alpine-release)
  echo "
    $MIRROR/v$alpine_release/main
    $MIRROR/v$alpine_release/community
    " | sed 's/^ *//' >$_ROOT/etc/apk/repositories
}

setup_sshd() {
  sed -i \
    -e 's/^#PasswordAuthentication .*/PasswordAuthentication yes/g' \
    -e 's/^#PubkeyAuthentication .*/PubkeyAuthentication yes/g' \
    -e 's/^#PermitRootLogin .*/PermitRootLogin no/g' \
    $_ROOT/etc/ssh/sshd_config
  echo "AllowUsers $XUSER" >> $_ROOT/etc/ssh/sshd_config
}

install_extra_apks() {
  echo "
    set -e
		apk update
    apk add sudo ufw curl docker docker-cli-compose
    /usr/sbin/ufw default deny incoming
    /usr/sbin/ufw allow ssh
    /usr/sbin/ufw enable
  " | sed -E 's/^ *//' | /usr/sbin/chroot $_ROOT /bin/sh -x 
}

setup_docker() {
  make_dir root:root 0755 "$_ROOT"/etc/docker
  echo '{
      "log-driver": "json-file",
      "log-opts": {"max-size": "10m", "max-file": "3"}
    }' | sed 's/^ {4}//' | make_file root:root 0644 "$_ROOT"/etc/docker/daemon.json
}

setup_user(){
  echo "$XUSER ALL=(ALL) ALL" | make_file root:root 0440 $_ROOT/etc/sudoers.d/$XUSER
  make_dir $XUSER:$XUSER 700 $_ROOT/home/$XUSER/.ssh
  sed -i '/^docker:/ s/$/'$XUSER'/' $_ROOT/etc/group
}

run() {
  check_env
  check_network
  call_setup_alpine
  mount_partitions
  configure_apu_console
  setup_network
  setup_sshd
  setup_docker
  setup_apk_repository
  install_extra_apks
  setup_user
  umount_partitions
}

run
