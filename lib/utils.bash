#!/usr/bin/env bash
set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
current_script_dir=$(dirname "${current_script_path}")

DOWNLOAD_URL="golang.org/dl"
TOOL_NAME="go-sdk"
TOOL_TEST="go version"
GO_SDK_PATH=
GO_SDK_LOW_LIMIT_VERSION="${GO_SDK_LOW_LIMIT_VERSION:-1.12.0}"

fail() {
  echo -e "asdf-$TOOL_NAME: $*" >/dev/stderr
  exit 1
}

sort_versions() {
  sed 'h; s/[+-]/./g; s/\([[:digit:]]\)\([[:alpha:]][[:alpha:]]*\)\([[:digit:]]\)/\1.0.\2.\3/; s/$/.0/; G; s/\n/ /' |
    LC_ALL=C sort -t . -k1,1n -k2,2n -k3,3n -k4,4n -k5,5n |
    awk '{print $2}'
}

sort_shim_versions() {
  sed 'h; s/^[^ ]*[[:space:]]//g; s/[+-]/./g; s/\([[:digit:]]\)\([[:alpha:]][[:alpha:]]*\)\([[:digit:]]\)/\1.0.\2.\3/; s/$/.0/; G; s/\n/ /' |
    LC_ALL=C sort -t . -k1,1n -k2,2n -k3,3n -k4,4n -k5,5n |
    awk '{print $2,$3}'
}

go_cmd_path() {
  local go_bin=
  local data_dir=${ASDR_DATA_DIR:-}
  if [[ -z $data_dir ]]; then
    data_dir=${ASDF_DIR}
  fi
  if [[ -e "${GOROOT:-''}" ]]; then
    go_bin=${GOROOT:-''}/bin/go
  else
    go_bin=$(type -ap go | grep -v "$data_dir" | head -n1)
  fi
  if [[ -z "${go_bin}" ]]; then
    # Use latest version shim of go
    local shim_version=()
    # shellcheck disable=SC2207
    shim_version=($(asdf shimversions go | grep -v unknown | sort_shim_versions | tail -n1))
    if [[ 2 -eq ${#shim_version[@]} ]]; then
      local upper_case
      upper_case=$(tr '[:lower:]-' '[:upper:]_' <<<"${shim_version[0]}")
      go_bin=$(
        eval "export ASDF_${upper_case}_VERSION=${shim_version[1]}"
        asdf which go
      )
    fi
  fi
  echo "${go_bin}"
}

go_cmd() {
  local go_bin
  go_bin=$(go_cmd_path)
  if [[ -z "$go_bin" ]]; then
    fail "go command not installed"
  fi
  ${go_bin} "$@"
}

go_plugin_tool() {
  # tools.go <command> [arguments]
  (
    cd "${current_script_dir}"

    # remove binary if can not execute
    if [[ -f "tools" ]] && ! ./tools version &>/dev/null; then
      rm ./tools
    fi

    if [[ ! -f "tools" || "tools.go" -nt "tools" ]]; then
      go_cmd build -o ./tools tools.go
    fi
    ./tools "$@"
  )
}

list_all_versions() {
  go_plugin_tool sdk-versions "${GO_SDK_LOW_LIMIT_VERSION}"
}

go_sdk_path() {
  if [[ -z "${GO_SDK_PATH}" ]]; then
    GO_SDK_PATH=$(go_plugin_tool sdk-path)
  fi
  echo "${GO_SDK_PATH}"
}

find_go_installed_bin() {
  local cmd=$1
  local find_path=()

  if [[ -n "${GOBIN:-}" ]]; then
    find_path+=("${GOBIN}")
  fi

  IFS=:

  for p in $(go_plugin_tool gopath); do
    if [[ -d "${p}/bin" ]]; then
      find_path+=("${p}/bin")
    fi
  done

  PATH="${find_path[*]}":$PATH type -p "$cmd"
}

list_installed_sdks() {
  shopt -s nullglob
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

  local resolved
  resolved=$(go_plugin_tool resolve-version "${version}")

  if [[ ${version} != "${resolved}" ]]; then
    # remove empty dir
    rmdir "${install_path}" || true
    install_path=${install_path/${version}/${resolved}}
    version=${resolved}
  fi

  if [[ -d "${install_path}" && -x "${install_path}/bin/${tool_cmd}" ]]; then
    echo "$TOOL_NAME $version installation was successful!"
    return
  fi

  # go version of semver (e.g. 1.16.3) to shell comparable string (e.g 011603)
  local go_comparable_version=
  go_comparable_version=$(go_plugin_tool version | awk -F . '{printf "%2d%02d%02d", $1, $2, $3}')

  (
    # Download go${version} into $GOPATH/bin
    if [[ ${go_comparable_version} -ge 11700 ]]; then
      echo go install "${DOWNLOAD_URL}/go${version}@latest"
      go_cmd install "${DOWNLOAD_URL}/go${version}@latest"
    else
      echo go get "${DOWNLOAD_URL}/go${version}"
      go_cmd get "${DOWNLOAD_URL}/go${version}"
    fi

    # Download Go SDK into GOROOT
    local go_bin
    go_bin=$(find_go_installed_bin "go${version}")

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
  go_bin=$(find_go_installed_bin "go${version}")

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
  local plugin_install_path
  plugin_install_path=${ASDF_INSTALL_PATH}

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
