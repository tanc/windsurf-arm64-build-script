#!/usr/bin/env bash

set -euo pipefail

# Versions
# WINDSURF_VERSION will be extracted from the downloaded tarball filename
# VSCODE_VERSION will be extracted from the source
# FD_VERSION will be discovered from the included fd binary

# URLs
# WINDSURF_SRC_URL will be discovered by the scraper script
# VSCODE_LINUX_ARM64_URL will be defined after extracting the version
# LANGUAGE_SERVER_ARM64_URL will be defined after extracting the version
# FD_ARM64_URL will be constructed after discovering the version

# Directories
BUILD_DIR="$(pwd)/build"
WINDSURF_SRC_DIR="${BUILD_DIR}/windsurf-src"
VSCODE_DIR="${BUILD_DIR}/vscode-linux-arm64"
FD_DIR="${BUILD_DIR}/fd-arm64"
OUTPUT_DIR="${BUILD_DIR}/output"
NO_REDOWNLOAD=false
if [ "${1:-}" = "--no-redownload" ]; then
  NO_REDOWNLOAD=true
fi

# Setup directories and download Windsurf source if needed
if [ "$NO_REDOWNLOAD" = false ]; then
  # Cleanup previous builds
  rm -rf "${BUILD_DIR}"

  # Create directories
  mkdir -p "${BUILD_DIR}" "${WINDSURF_SRC_DIR}" "${VSCODE_DIR}" "${FD_DIR}" "${OUTPUT_DIR}"

  # Get Windsurf source URL using the scraper
  echo "Building scraper image..."
  docker build -t windsurf-downloader . > /dev/null
  echo "Running scraper to find Windsurf source URL..."
  WINDSURF_SRC_URL=$(docker run --rm windsurf-downloader)

  if [ -z "$WINDSURF_SRC_URL" ]; then
    echo "Error: Could not get Windsurf source URL."
    exit 1
  fi
  echo "Found Windsurf source URL: ${WINDSURF_SRC_URL}"

  # Fetch Windsurf source
  echo "Downloading Windsurf source..."
  wget --show-progress -O "${BUILD_DIR}/windsurf-src.tar.gz" "${WINDSURF_SRC_URL}"

  # Extract Windsurf version from the tarball filename
  WINDSURF_VERSION=$(basename "${WINDSURF_SRC_URL}" | grep -oP '(?<=Windsurf-linux-x64-).*(?=\.tar\.gz)')

  if [ -z "$WINDSURF_VERSION" ]; then
    echo "Error: Could not extract WINDSURF_VERSION from URL: ${WINDSURF_SRC_URL}"
    exit 1
  fi

  # Save build info for subsequent runs
  echo "WINDSURF_SRC_URL='${WINDSURF_SRC_URL}'" > "${BUILD_DIR}/build_info.sh"
  echo "WINDSURF_VERSION='${WINDSURF_VERSION}'" >> "${BUILD_DIR}/build_info.sh"

else
  echo "Skipping download of Windsurf source."
fi

# Load build info
if [ ! -f "${BUILD_DIR}/build_info.sh" ]; then
  echo "Error: Build info not found. Please run a full build without --no-redownload first."
  exit 1
fi
source "${BUILD_DIR}/build_info.sh"
echo "Found Windsurf version: ${WINDSURF_VERSION}"

# Define final directory now that we have the version
FINAL_DIR="${OUTPUT_DIR}/windsurf_${WINDSURF_VERSION}_linux_arm64"

# Extract Windsurf source to get the language server version
echo "Extracting Windsurf source..."
tar -xzf "${BUILD_DIR}/windsurf-src.tar.gz" -C "${WINDSURF_SRC_DIR}" --strip-components=1

# Extract VS Code version from package.json
echo "Extracting VS Code version..."
PACKAGE_JSON_PATH="${WINDSURF_SRC_DIR}/resources/app/package.json"
if [ ! -f "$PACKAGE_JSON_PATH" ]; then
  echo "Error: package.json not found at ${PACKAGE_JSON_PATH}"
  exit 1
fi
VSCODE_VERSION=$(grep -m 1 '"version":' "${PACKAGE_JSON_PATH}" | cut -d '"' -f 4)
if [ -z "$VSCODE_VERSION" ]; then
  echo "Error: Could not extract VSCODE_VERSION from ${PACKAGE_JSON_PATH}"
  echo "Please specify it manually in the script."
  exit 1
fi
echo "Found VS Code version: ${VSCODE_VERSION}"

# Extract Language Server version
echo "Extracting Language Server and fd versions..."
EXTENSION_JS_PATH="${WINDSURF_SRC_DIR}/resources/app/extensions/windsurf/dist/extension.js"
if [ -z "$EXTENSION_JS_PATH" ]; then
  echo "Error: extension.js not found"
  exit 1
fi
LANGUAGE_SERVER_VERSION=$(grep -oP 'LANGUAGE_SERVER_VERSION="\K[0-9\.]+' "${EXTENSION_JS_PATH}")
if [ -z "$LANGUAGE_SERVER_VERSION" ]; then
  echo "Error: Could not extract LANGUAGE_SERVER_VERSION from ${EXTENSION_JS_PATH}"
  exit 1
fi
echo "Found Language Server version: ${LANGUAGE_SERVER_VERSION}"

# Extract fd version from the included binary
FD_X64_BIN_PATH="${WINDSURF_SRC_DIR}/resources/app/extensions/windsurf/bin"
if [ ! -f "${FD_X64_BIN_PATH}/fd" ]; then
  echo "Error: fd binary not found at ${FD_X64_BIN_PATH}"
  exit 1
fi

echo "Checking fd version..."
docker build -t fd-version-check -f Dockerfile.fd-check "${FD_X64_BIN_PATH}" > /dev/null
FD_VERSION_STRING=$(docker run --rm fd-version-check)
FD_VERSION=$(echo "${FD_VERSION_STRING}" | cut -d ' ' -f 2)
echo "Found fd version: v${FD_VERSION}"

# Define dynamic URLs
VSCODE_LINUX_ARM64_URL="https://update.code.visualstudio.com/${VSCODE_VERSION}/linux-arm64/stable"
LANGUAGE_SERVER_ARM64_URL="https://github.com/Exafunction/codeium/releases/download/language-server-v${LANGUAGE_SERVER_VERSION}/language_server_linux_arm"
FD_ARM64_URL="https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-aarch64-unknown-linux-gnu.tar.gz"

# Download remaining components if needed
if [ "$NO_REDOWNLOAD" = false ]; then
  echo "Downloading VS Code for Linux ARM64..."
  wget --show-progress -O "${BUILD_DIR}/vscode-linux-arm64.tar.gz" "${VSCODE_LINUX_ARM64_URL}"

  echo "Downloading Language Server for Linux ARM64..."
  wget --show-progress -O "${BUILD_DIR}/language-server-arm64" "${LANGUAGE_SERVER_ARM64_URL}"

  echo "Downloading fd for Linux ARM64..."
  wget --show-progress -O "${BUILD_DIR}/fd-arm64.tar.gz" "${FD_ARM64_URL}"

else
  echo "Skipping download of remaining components."
fi

# Extract components
echo "Extracting VS Code..."
tar -xzf "${BUILD_DIR}/vscode-linux-arm64.tar.gz" -C "${VSCODE_DIR}" --strip-components=1

echo "Extracting fd..."
tar -xzf "${BUILD_DIR}/fd-arm64.tar.gz" -C "${FD_DIR}" --strip-components=1

# Build Windsurf
echo "Building Windsurf..."
mkdir -p "${FINAL_DIR}"
cp -R "${VSCODE_DIR}/." "${FINAL_DIR}"

# Copy Windsurf-specific files
cp -R "${WINDSURF_SRC_DIR}/resources/app/out" "${FINAL_DIR}/resources/app/"
cp "${WINDSURF_SRC_DIR}/resources/app/package.json" "${FINAL_DIR}/resources/app/"
cp "${WINDSURF_SRC_DIR}/resources/app/product.json" "${FINAL_DIR}/resources/app/"
cp -R "${WINDSURF_SRC_DIR}/resources/app/extensions/"* "${FINAL_DIR}/resources/app/extensions/"

# Copy language server and fd, and make them executable
BIN_DEST_DIR="${FINAL_DIR}/resources/app/extensions/windsurf/bin"
mkdir -p "${BIN_DEST_DIR}"
cp "${BUILD_DIR}/language-server-arm64" "${BIN_DEST_DIR}/language_server_linux_arm"
cp "${FD_DIR}/fd" "${BIN_DEST_DIR}/fd"
chmod +x "${BIN_DEST_DIR}/language_server_linux_arm"
chmod +x "${BIN_DEST_DIR}/fd"

echo "Build complete!"
echo "Windsurf for Linux ARM64 is available at: ${FINAL_DIR}"

# Create final tarball
echo "Creating final tarball..."
ARTIFACT_NAME="windsurf_${WINDSURF_VERSION}_linux_arm64.tar.gz"
(cd "${OUTPUT_DIR}" && tar -czf "../../${ARTIFACT_NAME}" "$(basename "${FINAL_DIR}")")

echo "Build complete! Find the artifact at ./${ARTIFACT_NAME}"
