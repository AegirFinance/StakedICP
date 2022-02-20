#!/usr/bin/env bash

set -e

export NODE_ENV="$1"
if [ -z "$NODE_ENV" ]; then
  echo "usage: ./build.sh development/production" >&2
  exit 1
fi

dfx build --all
npm run build
