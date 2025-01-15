#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154,SC1003

current_dir="$(pwd)"
unypkg_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
unypkg_root_dir="$(cd -- "$unypkg_script_dir"/.. &>/dev/null && pwd)"

cd "$unypkg_root_dir" || exit

#############################################################################################
### Start of script

mkdir -pv /etc/uny/openresty/{sites-enabled,sites-available,conf.d} /var/www /var/log/openresty
if [[ ! -s /etc/uny/openresty/nginx.conf ]]; then
    cp -a nginx/conf/* /etc/uny/openresty/
fi

touch /var/log/openresty/error.log

# Adjustment to make opm work
#if [[ -s /bin/perl && ! -L /bin/perl ]]; then
#    mv -v /bin/perl /bin/perl_unybak
#    unyp si perl
#fi

OR_SERVICE_DEST="/etc/systemd/system/uny-openresty.service"
cp -a systemd/openresty.service "$OR_SERVICE_DEST"
#sed "s|.*Alias=.*||g" -i /etc/systemd/system/uny-ols.service
sed -e '/\[Install\]/a\' -e 'Alias=openresty.service or.service' -i "$OR_SERVICE_DEST"
systemctl daemon-reload

#############################################################################################
### End of script

cd "$current_dir" || exit
