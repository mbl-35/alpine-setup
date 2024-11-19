printf '%s\t%s\n%s\t\t%s\n' Installed Upgradable "$(apk list --install | wc -l)" "$(apk list --upgradable | wc -l)" > /etc/apk/status
