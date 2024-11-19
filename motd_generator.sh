#!/bin/sh
# NOTE// pour wsl docker: 
# ajouter le service de démarrage: apk add busybox-initscripts 
# et rc-service crond start && rc-update add crond

https://github.com/dylanaraps/neofetch/blob/master/neofetch
https://github.com/ar51an/raspberrypi-motd/blob/main/update-motd-static.d/20-update
https://geekscircuit.com/configure-authelia-with-nginx-proxy-manager/
https://www.smarthomebeginner.com/docker-authelia-tutorial/
https://github.com/anandslab/docker-traefik
https://unifi.ui.com/


ascii_bold='\e[1m'
ascii_italic='\e[3m'
reset='\e[0m'
# @see colors at https://robotmoon.com/256-colors/#shell-prompt
c1="$(printf '%b\e[38;5;111m' "$reset")${ascii_bold}" # blue
c2="$(printf '\e[37m%b' "$reset")${ascii_bold}"    # white
c3="$(printf '%b\e[38;5;183m' "$reset")${ascii_bold}" # cyan
c4="$(printf '%b\e[38;5;71m' "$reset")${ascii_bold}" # green
ds="\\\\\\"

info_first() { printf '%b\n' "\e[${text_padding}C${c1}${1}:${reset}@${c1}${2}${reset}"; }
info_percent() { printf '%b\n' "\e[${text_padding}C${c3}${1}:${reset} ${c4}${2}${reset}"; }
info(){ printf '%b\n' "\e[${text_padding}C${c3}${1}:${reset} ${2}"; }
info_cpu_usage(){ printf '%b\n' "\e[${text_padding}C${c3}${1}:${reset} ${c4}${2}${reset}"; }
info_mem(){ printf '%b\n' "\e[${text_padding}C${c3}${1}:${reset} ${2} (${c4}${3}${reset})"; }
info_disk(){ printf '%b\n' "\e[${text_padding}C${c3}${1}:${reset} ${2} (${c4}${3}${reset}) - ${4}"; }



printf '%b\n' "
   ${c1}/${ds} /${ds}
  /${c2}/ ${c1}${ds}  ${ds}
 /${c2}//  ${c1}${ds}  ${ds}
/${c2}//    ${c1}${ds}  ${ds}
${c2}//      ${c1}${ds}  ${ds}
         ${ds}"
ascii_high=6
ascii_width=15
ascii_gap=3
text_padding=$((ascii_width+ascii_gap))
printf '\e[%sA\e[9999999D' "${ascii_high}"

info_first "$(whoami)" "$(hostname)"
info "OS" "Alpine Linux $(cat /etc/alpine-release) $(uname -m)"
device_name=
device_info_path=/sys/devices/virtual/dmi/id/
[ -d $device_info_path ] && {
    device_name="$(cat $device_info_path/board_vendor)"
    device_productname="$(cat $device_info_path/product_name)"
    device_productversion="$(cat $device_info_path/product_version))"
    info "Host" "$device_name $device_productname $device_productversion"
}
info "Kernel" "$(uname -s) $(uname -r)"
uptime_seconds=$( cut -d '.' -f1 < /proc/uptime)
uptime_days=$(( uptime_seconds % 31556926 / 86400))
uptime_hours=$(( uptime_seconds % 31556926 % 86400 / 3600))
uptime_minutes=$(( uptime_seconds % 31556926 % 86400 % 3600 / 60))

info "Uptime" "$uptime_days days, $uptime_hours hours, $uptime_minutes minutes"
apk_status_file=/etc/apk/status
[ -f $apk_status_file ] && {
    # speedup..
    #info "Packages" "$(apk list --upgradable | wc -l) / $(apk list --installed | wc -l) (apk)"
    apk_info="$(cat $apk_status_file | tail -n 1)"
    apk_count="$( echo "$apk_info" | awk '{print $1}')"
    apk_upgradable="$( echo "$apk_info" | awk '{print $2}')"
    info "Packages" "$apk_upgradable / $apk_count (apk)"
}

info "CPU" "$(grep 'model name' /proc/cpuinfo | head -1 | cut -d':' -f2)"
info_cpu_usage "CPU Usage" "$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print int(usage) "%"}')"
info "LoadAvg" "$(awk -v OFS=', ' '{print $1,$2,$3}' /proc/loadavg)"

mem_label=MiB
mem_info="$(free -m | head -n 2 | tail -n 1)"
mem_total=$(echo "$mem_info" | awk '{print $2}')
mem_avail=$(echo "$mem_info" | awk '{print $4}')
mem_used=$((mem_total - mem_avail))
mem_perc=$((mem_used * 100 / mem_total))
info_mem "Memory" "$mem_used$mem_label / $mem_total$mem_label" "$mem_perc%"

swp_info="$(free -m | head -n 3 | tail -n 1)"
swp_total=$(echo "$swp_info" | awk '{print $2}')
swp_avail=$(echo "$swp_info" | awk '{print $4}')
swp_used=$((swp_total - swp_avail))
swp_perc=$((swp_used * 100 / swp_total))
info_mem "Swap" "$swp_used$mem_label / $swp_total$mem_label" "$swp_perc%"

mount_points="$(df -P -h | sed -n '1!p'| grep -v -E 'none|drivers|tmpfs' | sort -u -t' ' -k1,1 | awk '{print $6}')"
for i in  $mount_points ; do
  dsk_info="$(df -P -h "$i" | sed -n '1!p')"
  dsk_total="$(echo "$dsk_info" | awk '{print $2}')"
  dsk_used="$(echo "$dsk_info" | awk '{print $3}')"
  dsk_precent="$(echo "$dsk_info" | awk '{print $5}')"
  dsk_type="$(mount | sed -n '1!p'| grep -v -E 'none|drivers|tmpfs' | sort -u -t' ' -k1,1 | grep " on $i " | awk '{print $5}')"
  info_disk "Disk ($i)" "${dsk_used}iB / ${dsk_total}iB" "$dsk_precent" "$dsk_type"
done

for i in 0 1 2 ; do
    ip_addr="$(ifconfig eth$i 2>/dev/null | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}' )"
    ip_netmask="$(ifconfig eth$i  2>/dev/null | grep 'inet addr' | awk -F: '{print $4}')"
    if [ -n "$ip_addr" ]; then
        ip_prefix="$(ipcalc -p 1.1.1.1 "$ip_netmask" | sed -n 's/^PREFIX=\(.*\)/\/\1/p')"
        info "Local IP (eth$i)" "$ip_addr$ip_prefix"
    fi
done
printf '\n'
