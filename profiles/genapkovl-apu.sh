#!/bin/sh -e
# This is the script that will generate an `$HOSTNAME.apkovl.tar.gz` that
# will get baked into the `*.iso`. You could say this is the good stuff.
# And most of it is stolen/copied from: scripts/genapkovl-dhcp.sh
#
# @see:
#   - https://github.com/alpinelinux/aports/blob/master/scripts/genapkovl-dhcp.sh

HOSTNAME="$1"
[ -z "$HOSTNAME" ] && { echo "usage: $0 hostname"; exit 1; }

cleanup() { rm -rf "$tmp"; }

makedir() {
    OWNER="$1"
    PERMS="$2"
    DIR="$3"
    mkdir -p "$DIR"
    chown "$OWNER" "$DIR"
    chmod "$PERMS" "$DIR"
}

makefile() {
    OWNER="$1"
    PERMS="$2"
    FILENAME="$3"
    cat > "$FILENAME"
    chown "$OWNER" "$FILENAME"
    chmod "$PERMS" "$FILENAME"
}

rc_add() {
    mkdir -p "$tmp"/etc/runlevels/"$2"
    ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

# copy /etc
cp -r /transport/etc "$tmp"
chown -R root:root "$tmp"/etc


release=$(awk -F. -v OFS=. '{print $1,$2}' /etc/alpine-release)
makefile root:root 0644 "$tmp"/etc/apk/repositories <<EOF
http://mirrors.ircam.fr/pub/alpine/v$release/main
http://mirrors.ircam.fr/pub/alpine/v$release/community
EOF


# makefile root:root 0744 "$tmp"/etc/autosetup/90-reboot <<'EOF'
# #!/bin/sh
# set -e
# # Load setup-alpine.answers configuration variables
# . /etc/autosetup/setup-alpine.answers

# # Reboot only if we have lbu support
# if [ "${LBUOPTS}" != "none" ]; then
#     reboot
# fi
# EOF

# makefile root:root 0744 "$tmp"/etc/autosetup/setup-alpine.answers <<'EOF'
# # Use FR layout with FR variant
# KEYMAPOPTS="fr fr"

# # Set hostname
# HOSTNAMEOPTS="alpine-docker"

# # Set device manager to mdev
# DEVDOPTS=mdev

# # Contents of /etc/network/interfaces
# INTERFACESOPTS="auto lo
# iface lo inet loopback

# auto eth0
# iface eth0 inet dhcp

# auto eth1
# iface eth1 inet dhcp

# auto eth2
# iface eth2 inet dhcp
# "

# # Search domain of example.com, Google public nameserver
# # DNSOPTS="-d example.com 8.8.8.8"

# # Set timezone to UTC
# TIMEZONEOPTS="Europe/Paris"

# # set http/ftp proxy
# #PROXYOPTS="http://webproxy:8080"
# PROXYOPTS=none

# # Skip repositories setup and rely on our own apk/repositories from autosetup
# APKREPOSOPTS="-h"

# empty_root_password=1

# # Create admin "sysres" user
# USEROPTS="-a -u -g audio,video,netdev,sudo sysres"
# #USERSSHKEY="ssh-rsa AAA..." 
# #USERSHKEY="https://example.com/juser.keys"

# # Install Openssh
# SSHDOPTS=openssh
# #ROOTSSHKEY="ssh-rsa AAA..."
# #ROOTSSHKEY="https://example.com/juser.keys"

# # Use openntpd
# NTPOPTS="openntpd"

# # Use /dev/sda as a sys disk
# DISKOPTS="-m sys /dev/sda"
# #DISKOPTS=none

# # Setup config storage, if possible.
# LBUOPTS=none
# APKCACHEOPTS=none
# EOF

# Run setup-alpine
rc-add autosetup boot

# Start cgroups, required by docker
rc_add cgroups boot
rc_add docker boot

# Start ssh server
rc_add sshd boot

# Other init scripts
rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit 
rc_add hwdrivers sysinit
rc_add modloop sysinit
                       
rc_add hwclock boot                               
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot

rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
