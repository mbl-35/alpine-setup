#!/bin/bash

function usage() {
    cat <<EOF
Usage: ${PN} [Options] [Images ...] [Image:Tag]
Options:
  -h        : show this help message
  -f)       : force rebuild builder container
  -m)       : alpine mirror to use
  -p)       : profile to build (default apu:3.20:x86_64)

Builder Image:Tag supported format:
	ex: builder:latest
    ex: builder:1.2.3

Profile supported format
    ex: apu                apu profile, use default alpine&arch
    ex: apu:3.20           apu profile with alpine-3.20 & default arch
    ex: apu:3.20:x86_64    all specified
EOF
}

function _exit_with_msg() {
    echo "$1"
    exit 1
}

function merge_strings() {
    output="$1"
    if [ -n "$2" ]; then
        nb_sep1=$(echo "$1" | sed 's/[^:]//g' | awk '{print length+1}')
        nb_sep2=$(echo "$2" | sed 's/[^:]//g' | awk '{print length+1}')
        for i in $(seq 1 "$(( nb_sep2<nb_sep1 ? nb_sep2 : nb_sep2))" ) ; do 
            item="$(cut -d : -f "$i" <<< "$2")"
            [ -z "$item" ] || output="$(echo "$output" | awk -F: -v OFS=: -v INDEX="$i" '{$INDEX="'"$item"'"; print }')"
        done
    fi
    echo "$output" 
}

function get_profile_name() { echo "$1" | awk -F ':' '{print $1}'; }
function get_profile_alpine() { echo "$1" | awk -F ':' '{print $2}'; }
function get_profile_arch() { echo "$1" | awk -F ':' '{print $3}'; }
function get_container_name() { echo "$1" | awk -F ':' '{print $1}'; }
function get_container_version() { echo "$1" | awk -F ':' '{print $2}'; }

function exists_image() {
    $_DOCKER images | sed "1d" | awk '{print $1":"$2}' | grep "^$1$" >/dev/null
}

function rm_image_if_exists() {
    if exists_image "$1" ; then
        echo "Deleting existing container $1 ..."
        $_DOCKER image rm --force "$1"
    fi
}

function build_image() {
    rm_image_if_exists "$1"
    echo "Building $1 ..."
    alpine_version="$(get_container_version "$1")" 
    $_DOCKER build --build-arg ALPINE_VERSION="$alpine_version" --tag "$1" "$2"
}

function run() {
    echo "Building iso ..."
    container_image="$1"
    container_name="$(get_container_name "$container_image")"
    profile_name="$(get_profile_name "$2")"
    profile_alpine_version="$(get_profile_alpine "$2")"
    repo_version="$(awk -F. -v OFS=. '{print $1,$2}' <<< "$profile_alpine_version")"
    profile_arch="$(get_profile_arch "$2")"
    profile_path="${PD}/profiles"
    profile_iso="alpine-$profile_name-$profile_alpine_version-$profile_arch.iso"

    echo "Target file: ${profile_path}/$profile_iso"
    $_DOCKER run -it --privileged --rm \
        --name "$container_name" \
        -v "${profile_path}":/transport \
        "$container_image" \
        sh mkimage.sh \
        --tag "$profile_alpine_version" \
        --outdir /transport \
        --arch "$profile_arch" \
        --repository "$3/v$repo_version/main" \
        --repository "$3/v$repo_version/community" \
        --profile "$profile_name"
}

PN="${BASH_SOURCE[0]##*/}"
PD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

_DOCKER=docker
_APK_MIRROR=http://mirrors.ircam.fr/pub/alpine
_PROFILE="apu:3.20:x86_64"
_FLAG_REBUILD=

opt="$(getopt -o hfm:p: -- "$@")" || usage "Parse options failed"
eval set -- "${opt}"
while true; do
    case "${1}" in
    -h) usage; exit 0 ;;
    -f) _FLAG_REBUILD="1"; shift ;;
    -m) _APK_MIRROR="${2}"; shift 2 ;;
    -p) _PROFILE="$(merge_strings "$_PROFILE" "${2}")"; shift 2 ;;
    --) shift; break ;;
    *) _exit_with_msg "Internal error!" ;;
    esac
done

_profile_name="$(get_profile_name "$_PROFILE")"
_profile_alpine="$(get_profile_alpine "$_PROFILE")"
_aports_mkimg_file="${PD}/profiles/mkimg.$_profile_name.sh"
_aports_genapkovl_file="${PD}/profiles/genapkovl-$_profile_name.sh"
_builder="alpine-builder:$_profile_alpine"

[ -f "$_aports_mkimg_file" ] || 
    _exit_with_msg "Aports MKIMG file not found ($_aports_mkimg_file)"
[ -f "$_aports_genapkovl_file" ] || 
    _exit_with_msg "Aports GENAPKOVL file not found ($_aports_genapkovl_file)"

[ "$_FLAG_REBUILD" == "1" ] && rm_image_if_exists "$_builder"
exists_image "$_builder" || build_image "$_builder" ./docker

run "$_builder" "$_PROFILE" "$_APK_MIRROR"
