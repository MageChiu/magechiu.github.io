#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

HOST="${JEKYLL_HOST:-127.0.0.1}"
PORT="${JEKYLL_PORT:-4000}"
BASEURL="${JEKYLL_BASEURL:-}"
LIVERELOAD="${JEKYLL_LIVERELOAD:-true}"

cd "${REPO_ROOT}"

printf '\n[blog-dev] repo: %s\n' "${REPO_ROOT}"
printf '[blog-dev] host: http://%s:%s%s\n' "${HOST}" "${PORT}" "${BASEURL}"

if bundle check >/dev/null 2>&1; then
  printf '[blog-dev] bundle dependencies: ok\n'
else
  printf '[blog-dev] installing bundle dependencies...\n'
  bundle install
fi

printf '[blog-dev] cleaning old build artifacts...\n'
bundle exec jekyll clean

printf '[blog-dev] building site...\n'
bundle exec jekyll build --trace

SERVE_ARGS=(serve --host "${HOST}" --port "${PORT}" --baseurl "${BASEURL}" --trace)
if [[ "${LIVERELOAD}" == "true" ]]; then
  SERVE_ARGS+=(--livereload)
fi

printf '[blog-dev] starting local server...\n'
printf '[blog-dev] press Ctrl+C to stop\n\n'

bundle exec jekyll "${SERVE_ARGS[@]}"
