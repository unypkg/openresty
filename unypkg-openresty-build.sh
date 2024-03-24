#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091

set -vx

######################################################################################################################
### Setup Build System and GitHub

wget -qO- uny.nu/pkg | bash -s buildsys
mkdir /uny/tmp

### Installing build dependencies
unyp install pcre2

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/uny/build/github_conf

######################################################################################################################
### Timestamp & Download

uny_build_date_seconds_now="$(date +%s)"
uny_build_date_now="$(date -d @"$uny_build_date_seconds_now" +"%Y-%m-%dT%H.%M.%SZ")"

source /uny/uny/build/download_functions
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

check_for_repo_and_create
git_clone_source_repo

cd openresty || exit
make
cd /uny/sources || exit
mv openresty openrestysource
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
source /uny/build/functions
pkgname="openresty"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths_temp

####################################################
### Start of individual build script

unset LD_RUN_PATH

#    --with-cc-opt="-I/uny/pkg/pcre2/10.43/include/" \
#    --with-ld-opt="-L/uny/pkg/pcre2/10.43/lib/" \

./configure --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --with-pcre=/uny/pkg/pcre2/*/ \
    --with-pcre-jit \
    --with-mail \
    --with-ipv6 \
    -j"$(nproc)"

make -j"$(nproc)"

make install

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

cd /uny/pkg || exit
for pkg in /uny/sources/vdet-*-new; do
    vdet_content="$(cat "$pkg")"
    vdet_new_file="$pkg"
    pkg="$(echo "$pkg" | grep -Eo "vdet.*new$" | sed -e "s|vdet-||" -e "s|-new||")"
    pkgv="$(echo "$vdet_content" | head -n 1)"

    cp "$vdet_new_file" "$pkg"/"$pkgv"/vdet

    source_archive_orig="$(echo /uny/sources/"$pkg"-"$pkgv".tar.*)"
    source_archive_new="$(echo "$source_archive_orig" | sed -r -e "s|^.*/||" -e "s|(\.tar.*$)|-source\1|")"
    cp -a "$source_archive_orig" "$source_archive_new"
    cp -a /var/uny/build/logs/"$pkg"-*.log "$pkg"-build.log
    XZ_OPT="-9 --threads=0" tar -cJpf unypkg-"$pkg".tar.xz "$pkg"

    gh -R unypkg/"$pkg" release create "$pkgv"-"$uny_build_date_now" --generate-notes \
        "$pkg/$pkgv/vdet#vdet - $vdet_content" unypkg-"$pkg".tar.xz "$pkg"-build.log "$source_archive_new"
done
