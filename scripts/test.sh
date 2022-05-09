#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/common.sh"

MOC="$(vessel bin)/moc"
[ -e "$MOC" ] || (
  echo "moc binary not found" >&2
  exit 1
)

mkdir -p .temp
$MOC $(vessel sources) -wasi-system-api -o ./.temp/Test.wasm src/**/*Test.mo && wasmtime ./.temp/Test.wasm
