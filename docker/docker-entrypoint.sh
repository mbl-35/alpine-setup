#!/bin/sh
set -eu

cp /transport/*.sh "$APORTS_PATH/scripts/"
cd "$APORTS_PATH/scripts/"

exec sh mkimage.sh --outdir /transport "$@"
