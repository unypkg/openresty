#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091

set -vx

######################################################################################################################
### Setup Build System and GitHub

apt install -y perl dos2unix mercurial

wget -qO- uny.nu/pkg | bash -s buildsys
mkdir /uny/tmp

### Installing build dependencies
unyp install pcre2 openssl dos2unix

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/uny/build/github_conf
source /uny/uny/build/download_functions
source /uny/git/unypkg/fn

######################################################################################################################
### Timestamp & Download

uny_build_date_seconds_now="$(date +%s)"
uny_build_date_now="$(date -d @"$uny_build_date_seconds_now" +"%Y-%m-%dT%H.%M.%SZ")"

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

check_for_repo_and_create
git_clone_source_repo

cd openresty || exit
wget -O pcre.patch https://patch-diff.githubusercontent.com/raw/openresty/openresty/pull/956.patch
git apply pcre.patch
make

cd /uny/sources || exit
mv openresty openrestysource
rm openrestysource/openresty-*.tar.*
mv openrestysource/openresty-* openresty

cd openresty/bundle/ngx_stream_lua-* || exit
wget -O config.patch https://patch-diff.githubusercontent.com/raw/openresty/stream-lua-nginx-module/pull/335.patch
git apply config.patch
cd /uny/sources || exit

version_details
archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/build/functions
pkgname="openresty"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths_temp

####################################################
### Start of individual build script

unset LD_RUN_PATH

./configure --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --with-cc-opt="-I/uny/pkg/pcre2/10.43/include" \
    --with-ld-opt="-L/uny/pkg/pcre2/10.43/lib" \
    -j"$(nproc)" \
    --with-file-aio \
    --with-http_dav_module \
    --with-http_gzip_static_module \
    --with-http_realip_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-luajit \
    --with-pcre-jit \
    --with-http_v2_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-http_iconv_module

make -j"$(nproc)"

make install

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
