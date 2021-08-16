#!/usr/bin/env bash
set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
plugin_dir=$(dirname "$(dirname "$(dirname "$current_script_path")")")

# shellcheck source=../lib/utils.bash
source "${plugin_dir}/lib/utils.bash"

result=$(sync_installed_go_sdk)

if [[ -n "${result}" ]]; then
  cat <<<"${result}"
  asdf reshim "${TOOL_NAME}"
fi
