#!/bin/sh
#/boot/vmlinuz-lts modules=loop,squashfs,sd-mod,usb-storage nomodeset console=ttyS0,115200 initrd=/boot/initramfs-lts
set -ex

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

rc_add() {
    mkdir -p "$_ROOT/etc/runlevels/$2"
    ln -sf "/etc/init.d/$1" "$_ROOT/etc/runlevels/$2/$1"
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
    /usr/sbin/ufw default allow outgoing
    /usr/sbin/ufw default deny incoming
    /usr/sbin/ufw allow ssh
    /usr/sbin/ufw limit ssh
    /usr/sbin/ufw enable
  " | sed -E 's/^ *//' | /usr/sbin/chroot $_ROOT /bin/sh -x 
}

setup_ufw(){
  rc_add ufw default
}



setup_docker() {
  make_dir root:root 0755 "$_ROOT"/etc/docker
  echo '{
      "log-driver": "json-file",
      "log-opts": {"max-size": "10m", "max-file": "3"}
    }' | sed 's/^ {4}//' | make_file root:root 0644 "$_ROOT"/etc/docker/daemon.json
  
  rc_add docker boot
}

setup_user(){
  echo "$XUSER ALL=(ALL) ALL" | make_file root:root 0440 $_ROOT/etc/sudoers.d/$XUSER
  make_dir $XUSER:$XUSER 700 $_ROOT/home/$XUSER/.ssh
  sed -i '/^docker:/ s/$/'$XUSER'/' $_ROOT/etc/group
}

disable_root_login(){
  sed -i '/^root:/ s#/bin/sh#/sbin/nologin#' $_ROOT/etc/passwd
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
  setup_ufw
  setup_user
  disable_root_login
  umount_partitions
}

usage(){
  cat <<EOF
Usage: setup-apu2 [Options]
Options:
  -h        : show this help message
  -d        : target device (default: /dev/sda)
  -i        : network interface to setup (default: eth2)
  -k        : keymap to set (default: 'fr fr')
  -m        : apk mirror (default: http://mirrors.ircam.fr/pub/alpine)
  -n        : host name to set (default: alpine-docker)
  -t        : timezone (default: Europe/Paris)
  -u        : admin user (default: sysres)

EOF
}

#---------------------
XUSER=sysres
HOST=alpine-docker
KEYMAP="fr fr"
TIMEZONE="Europe/Paris"
MIRROR=http://mirrors.ircam.fr/pub/alpine
IFACE=eth2
TARGET_DEV=/dev/sda

_ROOT=/mnt/root
_BOOT=/mnt/boot

opt="$(getopt -o hd:i:k:m:n:t:u: -- "$@")" || usage "Parse options failed"
eval set -- "${opt}"
while true; do
    case "${1}" in
    -d) TARGET_DEV="${2}"; shift 2 ;;
    -h) usage; exit 0 ;;
    -i) IFACE="${2}"; shift 2 ;;
    -k) KEYMAP="${2}"; shift 2 ;;
    -m) MIRROR="${2}"; shift 2 ;;
    -n) HOST="${2}"; shift 2 ;;
    -t) TIMEZONE="${2}"; shift 2 ;;
    -u) XUSER="${2}"; shift 2 ;;
    --) shift; break ;;
    *) _exit_with_msg "Internal error!" ;;
    esac
done

run

# -------------
echo
echo "   USE OF THIS COMPUTING SYSTEM IS RESTRICTED TO THE AUTHORIZED USERS."
echo "   ALL INFORMATION AND COMMUNICATIONS ON THIS SYSTEM ARE SUBJECT TO REVIEW,"
echo "   MONITORING, AND RECORDING AT ANY TIME WITHOUT NOTICE."
echo "   UNAUTHORIZED ACCESS OR USE MAY BE SUBJECT TO PROSECUTION."
echo

/etc/profile.d/99motd.sh ??

mkdir /etc/periodic/5min
*/5 * * * * run-parts /etc/periodic/5min
rc-service crond start && rc-update add crond

/etc/motd
chmod +x motd

echo 'printf '"'"'%s\t%s\n%s\t\t%s\n'"'"' Installed Upgradable "$(apk list --install | wc -l)" "$(apk list --upgradable | wc -l)" > /etc/apk/status' 
>/etc/periodic/5min/apk-status
chmod +x /etc/periodic/5min/apk-status
# #!/bin/bash

# function color (){
#   echo "\e[$1m$2\e[0m"
# }

# function setCountColor (){
#   local input=$1
#   countColor="38;5;16;48;5;242"

#   if [ $input == 0 ]; then
#     countColor="38;5;16;48;5;242"
#   else
#     countColor="38;5;16;48;5;71"
#   fi
# }

# function msgFormat (){
#   local input=$1
#   local packagesPlural="s"

#   if [[ $input -eq 0 ||  $input -eq 1 ]]; then
#     packagesPlural=""
#   fi
#   echo "package$packagesPlural"
# }

# msgColor="38;5;103"

# # Count
# apt-get update --quiet=2
# pkgCount="$(apt-get -s dist-upgrade | grep -Po '^\d+(?= upgraded)')"
# setCountColor "$pkgCount"

# # Message
# msgHeader="$(color $msgColor \*)"
# msgCount="$(color $countColor " $pkgCount ")"
# msgLabel="$(color $msgColor "$(msgFormat $pkgCount) can be upgraded")"

# updateMsg=" $msgHeader $msgCount $msgLabel"

# # Output To Static Script
# OUT="/etc/update-motd.d/"$(basename $0)
# exec >${OUT}
# echo "#!/bin/bash"
# echo
# echo "#####################################################"
# echo "#              DO NOT EDIT THIS SCRIPT              #"
# echo "#     EDIT: /etc/update-motd-static.d/20-update     #"
# echo "#####################################################"
# echo "cat <<EOF"
# echo -e "\n$updateMsg\n"
# echo "EOF"