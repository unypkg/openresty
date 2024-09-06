#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154,SC1003

current_dir="$(pwd)"
unypkg_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
unypkg_root_dir="$(cd -- "$unypkg_script_dir"/.. &>/dev/null && pwd)"

cd "$unypkg_root_dir" || exit

#############################################################################################
### Start of script

cp -a systemd/openresty.service /etc/systemd/system/uny-openresty.service
#sed "s|.*Alias=.*||g" -i /etc/systemd/system/uny-ols.service
sed -e '/\[Install\]/a\' -e 'Alias=openresty.service or.service' -i /etc/systemd/system/uny-openresty.service
systemctl daemon-reload

#############################################################################################
### End of script

cd "$current_dir" || exit
