#!/bin/sh
# shellcheck disable=SC2034

# Basic profile data -- inherits from standard, but the main thing to make
# it work is the `apkovl=`. This is the script that configures most of the
# iso creation and allows you to control precooked packages and stuff.
# It also enables console on boot.
# @see: 
#   - https://github.com/alpinelinux/aports/blob/master/scripts/mkimg.standard.sh
#   - https://github.com/alpinelinux/aports/blob/master/scripts/mkimg.base.sh

profile_apu() {
    profile_standard
    profile_abbrev="apu"
    title="APU2 Alpine LiveCD"
	desc="APU2 AlpineLinux LiveCD"
    arch="aarch64 armv7 x86 x86_64"

    kernel_addons=
    kernel_flavors="virt"

    #initfs_cmdline="modules=loop,squashfs,sd-mod,usb-storage console=ttyS0,115200"
    kernel_cmdline="console=tty0 console=ttyS0,115200"
    syslinux_serial="0 115200"

    apkovl="genapkovl-apu.sh"

    #apks="$apks podman dropbear autossh python3 sudo"
    apks="$apks curl ufw docker docker-cli-compose sudo"
}
