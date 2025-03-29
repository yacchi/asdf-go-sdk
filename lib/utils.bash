#!/usr/bin/env bash
set -euo pipefail

current_script_path=${BASH_SOURCE[0]}
current_script_dir=$(dirname "${current_script_path}")

DOWNLOAD_URL="golang.org/dl"
TOOL_NAME="go-sdk"
TOOL_TEST="go version"
GO_SDK_PATH=
GO_SDK_LOW_LIMIT_VERSION="${GO_SDK_LOW_LIMIT_VERSION:-1.12.0}"
GO_SDK_LINK_DIR=sdk
GO_SDK_SHIM="${current_script_dir}/run"
GO_SDK_DOWNLOAD_URL="https://dl.google.com/go"
GO_SDK_INSTALL_PATH=$HOME/sdk
# https://github.com/golang/dl/blob/master/internal/version/version.go#L436-L438
GO_SDK_UNPACKED_SENTINEL=.unpacked-success
GO_SDK_BOOTSTRAP_VERSION=${GO_SDK_BOOTSTRAP_VERSION:-1.18.10}
GOLANG_DL_BROKEN118_VERSION=8125cd0cb02bf1ec91d6a06e70b95803598e76be

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

go_comparable_version() {
  local line version major=0 minor=0 patch=0

  # Read a single line from standard input
  read -r line

  # Extract the first match of go-version-like pattern: optional "go", digits.digits[.digits][suffix]
  if [[ $line =~ (go)?([0-9]+\.[0-9]+(\.[0-9]+)?([a-z]+[0-9]+)?) ]]; then
    version="${BASH_REMATCH[2]}"
  else
    echo "Invalid version format: $line" >&2
    return 1
  fi

  # Remove suffixes like rc1, beta1, etc.
  version=$(sed -E 's/(rc|beta)[0-9]+$//' <<<"$version")

  # Extract major, minor, and patch numbers (default patch to 0 if missing)
  IFS='.' read -r major minor patch < <(
    awk -F. '{ printf "%s.%s.%s", $1, $2, ($3 != "" ? $3 : "0") }' <<<"$version"
  )

  # Convert to comparable string with zero padding
  printf "%2d%02d%02d\n" "$major" "$minor" "$patch"
}

get_os() {
  local os
  os=$(uname -s | tr '[:upper:]' '[:lower:]')

  case $os in
  sunos)
    echo "solaris"
    ;;
  *)
    echo "$os"
    ;;
  esac
  return 0
}

get_arch() {
  local arch
  arch=$(uname -m)
  local os
  os=$(get_os)

  # Only apply necessary conversions
  case $arch in
  # Intel/AMD x86
  x86_64)
    echo "amd64"
    ;;
  i386 | i486 | i586 | i686 | i86pc)
    echo "386"
    ;;
  # ARM 64bit
  aarch64 | arm64)
    echo "arm64"
    ;;
  # ARM 32bit - OS specific handling
  arm*)
    # Convert ARM architecture based on OS
    case $os in
    linux)
      # Linux: supports armv6l and arm64
      echo "armv6l" # Convert all 32bit ARM to armv6l
      ;;
    darwin | windows)
      # macOS and Windows: only support arm64, 32bit ARM not supported
      echo "unsupported_arm"
      return 1
      ;;
    freebsd | netbsd | openbsd)
      # BSD variants: support arm and arm64
      echo "arm" # All 32bit simply as "arm"
      ;;
    plan9)
      # Plan9: only supports arm
      echo "arm"
      ;;
    *)
      # Return architecture as is for other OSes
      echo "$arch"
      ;;
    esac
    ;;
  # MIPS variants
  mipsel)
    echo "mipsle"
    ;;
  mips64el)
    echo "mips64le"
    ;;
  # Loongson
  loongarch64)
    echo "loong64"
    ;;
  # Return as is for other architectures
  *)
    echo "$arch"
    ;;
  esac
  return 0
}

download_cmd() {
  local url="$1"
  local dest="$2"
  local options=()
  local progress=${progress:-}

  if command -v curl &>/dev/null; then
    options=(-fsSL)
    if [[ "$progress" = "1" ]]; then
      options=(-fL#)
    fi
    curl "${options[@]}" "$url" -o "$dest"
    return $?
  elif command -v wget &>/dev/null; then
    options=(--quiet)
    if [[ "$progress" = "1" ]]; then
      options=(--quiet --show-progress)
    fi
    wget "${options[@]}" "$url" -O "$dest"
    return $?
  else
    echo "Error: Neither curl nor wget is installed"
    return 1
  fi
}

calc_sha256_sum() {
  local file="$1"

  if command -v sha256sum &>/dev/null; then
    sha256sum "$file"
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$file"
  else
    fail "Neither sha256sum nor shasum is installed"
  fi
}

download_and_install_gosdk() {
  local go_version=${1}
  local install_dir=${2}

  # Detect OS and architecture
  local os
  os=$(get_os)
  local arch
  arch=$(get_arch)

  local go_bin="${install_dir}/bin/go"
  local download_url="${GO_SDK_DOWNLOAD_URL}/go${go_version}.${os}-${arch}.tar.gz"
  local checksum_url="${download_url}.sha256"
  local tar_file="go${go_version}.${os}-${arch}.tar.gz"
  local checksum_file="${tar_file}.sha256"
  local temp_dir="${install_dir}.tmp"

  download() {
    # Create installation directory
    echo "Downloading Golang version ${go_version} (${os}-${arch})..."

    mkdir -p "${temp_dir}" || fail "Failed to create installation directory"

    (
      # Download archive
      echo "Downloading archive: ${download_url}"
      if ! progress=1 download_cmd "${download_url}" "${temp_dir}/${tar_file}"; then
        fail "Failed to download archive"
      fi

      # Download checksum file
      echo "Downloading checksum: ${checksum_url}"
      if ! download_cmd "${checksum_url}" "${temp_dir}/${checksum_file}"; then
        fail "Failed to download checksum file"
      fi

      # Verify integrity
      local expected_checksum
      expected_checksum=$(<"${temp_dir}/${checksum_file}")
      local computed_checksum
      computed_checksum=$(calc_sha256_sum "${temp_dir}/${tar_file}" | awk '{print $1}')

      if [ "${expected_checksum}" = "${computed_checksum}" ]; then
        # Extract to installation directory
        echo "Extracting Golang to ${install_dir}..."

        if tar -C "${temp_dir}" -xf "${temp_dir}/${tar_file}"; then
          # Move contents from go subdirectory to install_dir and remove the empty go directory
          if [[ ! -d "${temp_dir}/go" ]]; then
            fail "Failed to find go directory in extracted files"
          fi
          mv "${temp_dir}/go" "${install_dir}"

          # Create a sentinel file to indicate successful unpacking
          touch "${install_dir}/${GO_SDK_UNPACKED_SENTINEL}"

          echo "Golang version ${go_version} has been installed to ${install_dir}/go"
        else
          fail "Failed to extract archive"
        fi
      else
        fail "Checksum verification failed! File may be corrupted. Please try again."
      fi
    )

    local result=$?

    # Cleanup
    rm -r "${temp_dir}" || true

    return $result
  }

  if [[ ! -x "${go_bin}" ]]; then
    download || exit $?
  fi

  local comparable_version
  comparable_version=$(${go_bin} version | go_comparable_version)

  # Download go${version} into $GOPATH/bin
  if [[ ${comparable_version} -ge 11900 ]]; then
    echo "${go_bin}" install "${DOWNLOAD_URL}/go${go_version}@latest"
    "${go_bin}" install "${DOWNLOAD_URL}/go${go_version}@latest"
  elif [[ ${comparable_version} -ge 11700 ]]; then
    echo "${go_bin}" install "${DOWNLOAD_URL}/go${go_version}@${GOLANG_DL_BROKEN118_VERSION}"
    "${go_bin}" install "${DOWNLOAD_URL}/go${go_version}@${GOLANG_DL_BROKEN118_VERSION}"
  else
    echo "${go_bin}" get "${DOWNLOAD_URL}/go${go_version}@${GOLANG_DL_BROKEN118_VERSION}"
    GO111MODULE=on "${go_bin}" get "${DOWNLOAD_URL}/go${go_version}@${GOLANG_DL_BROKEN118_VERSION}"
  fi
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
  local comparable_version
  if [[ -x ${go_bin} ]]; then
    comparable_version=$("${go_bin}" version | go_comparable_version)
  fi
  local bootstrap_comparable_version
  bootstrap_comparable_version=$(go_comparable_version <<<"${GO_SDK_BOOTSTRAP_VERSION}")

  # Install bootstrap go version if not installed or version < GO_SDK_BOOTSTRAP_VERSION
  if [[ -z "$go_bin" ]] || [[ $comparable_version -lt $bootstrap_comparable_version ]]; then
    local go_version=${GO_SDK_BOOTSTRAP_VERSION}
    if [[ "$go_version" < "${ASDF_INSTALL_VERSION:-}" ]]; then
      # Use the version specified in ASDF_INSTALL_VERSION
      go_version=${ASDF_INSTALL_VERSION}
    fi
    download_and_install_gosdk "${go_version}" "${GO_SDK_INSTALL_PATH}/go${go_version}" >&2
    go_bin="${GO_SDK_INSTALL_PATH}/go${go_version}/bin/go"
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

  if [[ ${#find_path[@]} -eq 0 ]]; then
    type -p "$cmd"
  else
    PATH="${find_path[*]}":$PATH type -p "$cmd"
  fi
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

  (
    local go_bin
    go_bin=$(find_go_installed_bin "go${version}" || true)

    if [[ -z "${go_bin}" ]]; then
      download_and_install_gosdk "${version}" "${GO_SDK_INSTALL_PATH}/go${version}"
    fi

    sync_installed_go_sdk_for_version "${install_path}"

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
  local sdk_link="${install_path}/${GO_SDK_LINK_DIR}"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release uninstalls only"
  fi

  local go_bin
  go_bin=$(find_go_installed_bin "go${version}" || true)

  if [[ -f "${go_bin}" ]]; then
    rm "${go_bin}"
  fi

  if [[ -e "${sdk_link}" ]]; then
    # Remove GOROOT for version
    rm -r "$(realpath "${sdk_link}")"
  fi

  sync_installed_go_sdk_for_version "${install_path}"
}

sync_installed_go_sdk_for_version() {
  local plugin_install_path
  local version=
  local sdk_link
  plugin_install_path="$1"
  version="${plugin_install_path##*/}"
  sdk_link="${plugin_install_path}/${GO_SDK_LINK_DIR}"

  if [[ -e "${plugin_install_path}" && -L "${sdk_link}" && ! -e ${sdk_link} ]]; then
    # uninstall
    echo "Unlink not installed SDK of ${version}"
    rm -r "${plugin_install_path}"
    return
  fi

  # install
  local sdk
  if [[ -e ${sdk_link} ]]; then
    sdk=$(realpath "${sdk_link}")
  else
    local go_bin
    go_bin=$(find_go_installed_bin "go${version}" || true)
    if [[ -z "${go_bin}" ]]; then
      echo "Go version ${version} not installed"
      return
    fi
    sdk=$(${go_bin} env GOROOT)
  fi

  if [[ -e "${plugin_install_path}" && ! -e "${sdk_link}" ]]; then
    rm -r "${plugin_install_path}"
  fi

  if [[ ! -d "${plugin_install_path}" ]]; then
    mkdir -p "${plugin_install_path}"
  fi

  if [[ ! -e "${sdk_link}" ]]; then
    echo "Link installed SDK of ${version} to ${sdk}"
    ln -s "${sdk}" "${sdk_link}"
  fi

  create_bin "${sdk}" "${plugin_install_path}"
}

create_bin() {
  local goroot="$1"
  local install_path="$2"
  local sdk_bin

  if [[ ! -d "${install_path}/bin" ]]; then
    mkdir -p "${install_path}/bin"
  fi

  for sdk_bin in "${goroot}/bin/"*; do
    local bin_path
    local cmd_name=${sdk_bin##*/}
    bin_path="${install_path}/bin/${cmd_name}"
    ln -sf "${GO_SDK_SHIM}" "${bin_path}"
  done
}

sync_installed_go_sdk() {
  local plugin_install_path
  local installed
  plugin_install_path=${ASDF_INSTALL_PATH:-"$ASDF_DIR/installs/$TOOL_NAME"}

  if [[ $plugin_install_path == */$TOOL_NAME/* ]]; then
    sync_installed_go_sdk_for_version "${plugin_install_path}"
    return
  fi

  if [[ ! -d "${plugin_install_path}" ]]; then
    mkdir -p "${plugin_install_path}"
  fi

  for installed in "${plugin_install_path}"/*; do
    sync_installed_go_sdk_for_version "${installed}"
  done

  for sdk in $(list_installed_sdks); do
    local version="${sdk#*/go}"
    local installed="${plugin_install_path}/${version}"
    sync_installed_go_sdk_for_version "${installed}"
  done
}
