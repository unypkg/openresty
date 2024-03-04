#!/usr/bin/env bash

######################################################################################################################
### Download
# shellcheck disable=SC1091
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

check_for_repo_and_create
git_clone_source_repo

cd openresty || exit

version_details
archiving_source
