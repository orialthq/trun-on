#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SERVER_DIR=$(dirname -- "$SCRIPT_DIR")

if ! command -v security >/dev/null 2>&1; then
  echo "macOS security 명령을 찾을 수 없습니다." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js 20 이상이 필요합니다." >&2
  exit 1
fi

if ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 20 ? 0 : 1)'; then
  echo "Node.js 20 이상이 필요합니다." >&2
  exit 1
fi

if ! OPENAI_API_KEY=$(
  security find-generic-password \
    -a "ori-beauty" \
    -s "ori-beauty-openai" \
    -w 2>/dev/null
); then
  echo "키체인에서 ori-beauty-openai 키를 찾을 수 없습니다." >&2
  exit 1
fi

if [ -z "$OPENAI_API_KEY" ]; then
  echo "키체인에 저장된 키가 비어 있습니다." >&2
  exit 1
fi

export OPENAI_API_KEY
cd "$SERVER_DIR"
exec node src/index.js
