#!/usr/bin/env bash
set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
current_script_dir=$(dirname "${current_script_path}")

DOWNLOAD_URL="golang.org/dl"
TOOL_NAME="go-sdk"
TOOL_TEST="go version"
GO_SDK_PATH=

# shellcheck disable=SC1090
source "${ASDF_DIR:-$HOME/.asdf}/lib/utils.bash"

plugin_install_path=$(dirname "$(get_install_path ${TOOL_NAME} version DUMMY)")

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

go_cmd() {
  local go_bin
  if [[ -e "${GOROOT:-''}" ]]; then
    go_bin=${GOROOT:-''}/bin/go
  else
    go_bin=$(type -ap go | grep -v "$(asdf_data_dir)" | head -n1)
  fi
  if [[ -z "$go_bin" ]]; then
    echo "go command not installed"
    exit 1
  fi

  ${go_bin} "$@"
}

go_plugin_tool() {
  # tools.go <command> [arguments]
  (
    cd "${current_script_dir}"
    go_cmd run "tools.go" "$@"
  )
}

list_all_versions() {
  go_plugin_tool sdk-versions
}

go_sdk_path() {
  if [[ -z "${GO_SDK_PATH}" ]]; then
    go_plugin_tool sdk-path
  fi
  echo "${GO_SDK_PATH}"
}

go_gopath_bin() {
  echo "$(go_plugin_tool gopath)"/bin
}

list_installed_sdks() {
  for sdk in "$(go_sdk_path)"/go*; do
    echo "${sdk}"
  done
}

list_installed_versions() {
  for sdk in $(list_installed_sdks); do
    echo "${sdk#*/go}"
  done
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  local tool_cmd
  tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"

  if [[ -d "${install_path}" && -x "${install_path}/bin/${tool_cmd}" ]]; then
    echo "$TOOL_NAME $version installation was successful!"
    return
  fi

  (
    # Download go${version} into $GOPATH/bin
    echo go get "${DOWNLOAD_URL}/go${version}"
    go_cmd get "${DOWNLOAD_URL}/go${version}"

    # Download Go SDK into GOROOT
    local go_bin
    go_bin="$(go_gopath_bin)/go${version}"

    ${go_bin} download

    # Remove exists dir for VERSION before create symlink
    [[ -d "${install_path}" ]] && rm -r "${install_path}"
    ln -s "$(${go_bin} env GOROOT)" "${install_path}"

    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}

uninstall_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release uninstalls only"
  fi

  local go_bin
  go_bin="$(go_gopath_bin)/go${version}"

  if [[ -f "${go_bin}" ]]; then
    rm "${go_bin}"
  fi

  if [[ -L "${install_path}" ]]; then
    # Remove GOROOT for version
    rm -r "$(readlink "${install_path}")"
    # Remove link from asdf install dir
    rm "${install_path}"
  elif [[ -d "${install_path}" ]]; then
    rm -r "${install_path}"
  fi
}

sync_installed_go_sdk() {
  if [[ ! -d "${plugin_install_path}" ]]; then
    mkdir -p "${plugin_install_path}"
  fi

  for installed in "${plugin_install_path}"/*; do
    if [[ -L "${installed}" && ! -e "${installed}" ]]; then
      echo "Unlink not installed SDK of $(basename "${installed}")"
      rm "${installed}"
    fi
  done

  for sdk in $(list_installed_sdks); do
    local version="${sdk#*/go}"
    local installed="${plugin_install_path}/${version}"

    if [[ -e "${installed}" && ! -L "${installed}" ]]; then
      rm -r "${installed}"
    fi

    if [[ ! -e "${installed}" ]]; then
      echo "Link installed SDK of ${version}"
      ln -s "${sdk}" "${installed}"
    fi
  done
}
