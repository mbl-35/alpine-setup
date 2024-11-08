# APU2 Alpine bootstrap

Because I can't challenge the alpine mkimage tool properly and spent to mutch time with it..

```
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
```
### Use this script
- Get the Standard ISO Edition **x86_64** released on [Alpine Download site](https://www.alpinelinux.org/downloads/)
- Flash USB with etcher
- Assume eth2 (or need changes) is plugged and a dhcp server can serve it
- Assume you have a USB serial cable between APU and your desktop
- Plug USB to APU and turn it on. Press F10 to choose boot USB media
- Quickly press '/' to enter the boot sequence to have console
  ```sh
  #/boot/vmlinuz-lts modules=loop,squashfs,sd-mod,usb-storage nomodeset console=ttyS0,115200 initrd=/boot/initramfs-lts
  ```

then from console:
- wait for boot sequence until login prompt
- log as `root` (no password)
- check network is up `wget --spider www.google.com`
  > if no network, activate interface with following commands and recheck
    ```sh
     $ ifconfig eth2 up
     $ udhcpc -i eth2
    ```
- download installation script and start it
  ```
  $ wget https://github.com/mbl-35/alpine-setup/raw/refs/heads/main/setup-apu2.sh
  $ sh ./setup-apu2.sh [user (default:sysres)]
  ```
- during installation, only confirm to erase the specified device:
   ```sh
   WARNING: The following disk(s) will be erased:
      sda   (16.0 GB ATA      SATA SSD)
  WARNING: Erase the above disk(s) and continue? (y/n) [n] y
   ```
- remove USB stick and **reboot**

after, from console:
- login with created admin user (`-u` option, no password)
- set your password `passwd`
- you're ready to work :)


### Features

- [x] check connectivity
- [x] generate answer file for `setup-alpine` and call it
- [x] mount created partitions for updating
- [x] configure console for APUs
- [x] add specific apk repos (main/community)
- [x] add extra packages (ufw/curl/docker)
- [x] configure extra packages and user
- [x] disable root login
- [x] flexibility with input parameters
