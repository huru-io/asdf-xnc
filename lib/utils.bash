#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/huru-io/xnullclaw"
TOOL_NAME="xnc"
TOOL_TEST="xnc --version"

fail() {
  echo -e "asdf-$TOOL_NAME: $*" >&2
  exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//'
}

list_all_versions() {
  list_github_tags
}

get_platform() {
  local os
  os="$(uname -s)"
  case "$os" in
    Linux*) echo "linux" ;;
    Darwin*) echo "darwin" ;;
    *) fail "Unsupported OS: $os" ;;
  esac
}

get_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *) fail "Unsupported architecture: $arch" ;;
  esac
}

get_download_url() {
  local version="$1"
  local platform="$2"
  local arch="$3"
  echo "${GH_REPO}/releases/download/v${version}/${TOOL_NAME}_v${version}_${platform}_${arch}.tar.gz"
}

download_release() {
  local version="$1"
  local filename="$2"
  local platform arch url

  platform="$(get_platform)"
  arch="$(get_arch)"
  url="$(get_download_url "$version" "$platform" "$arch")"

  echo "* Downloading $TOOL_NAME release $version ($platform/$arch)..."
  curl "${curl_opts[@]}" -o "$filename" "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="${3%/bin}/bin"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    chmod +x "$install_path/$tool_cmd"
    test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error occurred while installing $TOOL_NAME $version."
  )
}
