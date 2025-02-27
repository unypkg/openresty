#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

apt install -y perl dos2unix mercurial

wget -qO- uny.nu/pkg | bash -s buildsys

### Installing build dependencies
unyp install pcre2 openssl dos2unix

#pip3_bin=(/uny/pkg/python/*/bin/pip3)
#"${pip3_bin[0]}" install meson

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/git/unypkg/fn
uny_auto_github_conf

######################################################################################################################
### Timestamp & Download

uny_build_date

mkdir -pv /uny/sources
cd /uny/sources || exit

pkgname="openresty"
pkggit="https://github.com/openresty/openresty.git refs/tags/v*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "v[0-9.]*$" | tail --lines=1)"
latest_ver="$(echo "$latest_head" | grep -o "v[0-9.]*" | sed "s|v||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

git_clone_source_repo

cd openresty || exit
#wget -O pcre.patch https://patch-diff.githubusercontent.com/raw/openresty/openresty/pull/956.patch
#git apply pcre.patch
make

cd /uny/sources || exit
mv openresty openrestysource
rm openrestysource/openresty-*.tar.*
mv openrestysource/openresty-* openresty

lua_resty_http_latest_ver="$(git ls-remote --refs --tags --sort="v:refname" https://github.com/ledgetech/lua-resty-http refs/tags/v* | grep -E "v[0-9.]*$" | tail --lines=1 | cut -f2 | sed "s|refs/tags/||")"
git clone --depth 1 --branch "$lua_resty_http_latest_ver" https://github.com/ledgetech/lua-resty-http

#cd openresty/bundle/ngx_stream_lua-* || exit
#wget -O config.patch https://patch-diff.githubusercontent.com/raw/openresty/stream-lua-nginx-module/pull/335.patch
#git apply config.patch
#cd /uny/sources || exit

archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/git/unypkg/fn

pkgname="openresty"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths_temp

####################################################
### Start of individual build script

#unset LD_RUN_PATH

#pcre2_path=(/uny/pkg/pcre2/*/)
#    --with-cc-opt="-I${pcre2_path[0]}include" \
#    --with-ld-opt="-L${pcre2_path[0]}lib" \

./configure --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --with-ld-opt="$LDFLAGS" \
    --conf-path=/etc/uny/openresty/nginx.conf \
    --with-openssl-opt=enable-ec_nistp_64_gcc_128 \
    --with-openssl-opt=no-weak-ssl-ciphers \
    --with-pcre-jit \
    --with-luajit \
    --with-file-aio \
    --with-http_dav_module \
    --with-http_gzip_static_module \
    --with-http_realip_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-http_v2_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-http_iconv_module \
    -j"$(nproc)"

make -j"$(nproc)"

make install

mkdir -pv /uny/pkg/"$pkgname"/"$pkgver"/nginx/conf
cp -a /etc/uny/openresty/* /uny/pkg/"$pkgname"/"$pkgver"/nginx/conf/

cp -a /sources/lua-resty-http/lib/resty/* /uny/pkg/"$pkgname"/"$pkgver"/lualib/resty/

mkdir -pv /uny/pkg/"$pkgname"/"$pkgver"/systemd
tee /uny/pkg/"$pkgname"/"$pkgver"/systemd/openresty.service <<EOF
[Unit]
Description=The OpenResty Application Platform
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/uny/pkg/$pkgname/$pkgver/nginx/logs/nginx.pid
ExecStartPre=/uny/pkg/$pkgname/$pkgver/nginx/sbin/nginx -t
ExecStart=/uny/pkg/$pkgname/$pkgver/nginx/sbin/nginx
ExecStartPost=/usr/bin/env bash -c "sleep 1"
ExecReload=/usr/bin/env bash -c "kill -s HUP \$MAINPID"
ExecStop=/usr/bin/env bash -c "kill -s QUIT \$MAINPID"
RuntimeDirectory=openresty
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars

# nginx dependencies
echo "Shared objects required by: nginx"
ldd /uny/pkg/"$pkgname"/"$pkgver"/nginx/sbin/nginx
ldd /uny/pkg/"$pkgname"/"$pkgver"/nginx/sbin/nginx | grep -v "$pkgname/$pkgver" | sed "s|^.*ld-linux.*||" | grep -o "uny/pkg\(.*\)" | sed -e "s+uny/pkg/+unypkg/+" | grep -Eo "(unypkg/[a-z0-9]+/[0-9.]*)" |
    sort -u >>/uny/pkg/"$pkgname"/"$pkgver"/rdep
sort -u /uny/pkg/"$pkgname"/"$pkgver"/rdep -o /uny/pkg/"$pkgname"/"$pkgver"/rdep
echo "Packages required by unypkg/$pkgname/$pkgver:"
cat /uny/pkg/"$pkgname"/"$pkgver"/rdep

cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
