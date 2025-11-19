#!/usr/bin/env bash

# Build Windsurf for Linux ARM64 by:
# 1. Scraping the official Windsurf Linux x64 download URL via a Docker-based scraper.
# 2. Extracting the Windsurf version and commit hash from that URL.
# 3. Downloading VS Code for Linux ARM64 for the core application binaries.
# 4. Downloading the Windsurf server for Linux ARM64 to get fd and the language server.
# 5. Combining these pieces into a final Windsurf Linux ARM64 build and tarball.

set -euo pipefail

# Enable debug output
set -x

# Versions
# WINDSURF_VERSION is extracted from the Windsurf Linux x64 tarball filename
# VSCODE_VERSION is extracted from the Windsurf source package.json

# URLs
# WINDSURF_SRC_URL is discovered by the scraper container
# VSCODE_LINUX_ARM64_URL is constructed using VSCODE_VERSION
# WINDSURF_SERVER_URL is constructed from WINDSURF_VERSION and the commit hash

# Directories
BUILD_DIR="$(pwd)/build"
WINDSURF_SRC_DIR="${BUILD_DIR}/windsurf-src"
VSCODE_DIR="${BUILD_DIR}/vscode-linux-arm64"
WINDSURF_SERVER_DIR="${BUILD_DIR}/windsurf-server-linux-arm64"
OUTPUT_DIR="${BUILD_DIR}/output"

# Parse command line arguments
NO_REDOWNLOAD=false
USER_FD_VERSION=""
for arg in "$@"; do
  if [ "$arg" = "--no-redownload" ]; then
    NO_REDOWNLOAD=true
  elif [[ "$arg" =~ ^--fd-version=([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    USER_FD_VERSION="${BASH_REMATCH[1]}"
    echo "Using user-specified fd version: $USER_FD_VERSION"
  fi
done

# Detect host architecture
HOST_ARCH=$(uname -m)
echo "Host architecture: $HOST_ARCH"

# Setup directories and download Windsurf source if needed
if [ "$NO_REDOWNLOAD" = false ]; then
  # Cleanup previous builds
  rm -rf "${BUILD_DIR}"

  # Create directories
  mkdir -p "${BUILD_DIR}" "${WINDSURF_SRC_DIR}" "${VSCODE_DIR}" "${OUTPUT_DIR}"

  # Get Windsurf source URL using the scraper
  echo "Building scraper image..."
  docker build -t windsurf-downloader .
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

  # Extract commit hash from the Windsurf source URL
  WINDSURF_COMMIT_HASH=$(echo "${WINDSURF_SRC_URL}" | sed -E 's#.*/stable/([^/]+)/Windsurf-linux-x64-.*#\1#')

  if [ -z "$WINDSURF_COMMIT_HASH" ]; then
    echo "Error: Could not extract WINDSURF_COMMIT_HASH from URL: ${WINDSURF_SRC_URL}"
    exit 1
  fi

  # Save build info for subsequent runs
  echo "WINDSURF_SRC_URL='${WINDSURF_SRC_URL}'" > "${BUILD_DIR}/build_info.sh"
  echo "WINDSURF_VERSION='${WINDSURF_VERSION}'" >> "${BUILD_DIR}/build_info.sh"
  echo "WINDSURF_COMMIT_HASH='${WINDSURF_COMMIT_HASH}'" >> "${BUILD_DIR}/build_info.sh"

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
echo "Using Windsurf commit hash: ${WINDSURF_COMMIT_HASH}"

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

echo "Extracting Language Server and fd versions from Windsurf source (no external downloads needed)..."
EXTENSION_JS_PATH="${WINDSURF_SRC_DIR}/resources/app/extensions/windsurf/dist/extension.js"
if [ -z "$EXTENSION_JS_PATH" ]; then
  echo "Error: extension.js not found"
  exit 1
fi

# Define dynamic URLs
VSCODE_LINUX_ARM64_URL="https://update.code.visualstudio.com/${VSCODE_VERSION}/linux-arm64/stable"
WINDSURF_SERVER_ARCHIVE_NAME="windsurf-reh-linux-arm64-${WINDSURF_VERSION}.tar.gz"
WINDSURF_SERVER_URL="https://windsurf-stable.codeiumdata.com/linux-reh-arm64/stable/${WINDSURF_COMMIT_HASH}/${WINDSURF_SERVER_ARCHIVE_NAME}"

# Download remaining components if needed
if [ "$NO_REDOWNLOAD" = false ]; then
  echo "Downloading VS Code for Linux ARM64..."
  wget --show-progress -O "${BUILD_DIR}/vscode-linux-arm64.tar.gz" "${VSCODE_LINUX_ARM64_URL}"

  echo "Downloading Windsurf server for Linux ARM64..."
  wget --show-progress -O "${BUILD_DIR}/${WINDSURF_SERVER_ARCHIVE_NAME}" "${WINDSURF_SERVER_URL}"

else
  echo "Skipping download of remaining components."
fi

# Extract components
echo "Extracting VS Code..."
tar -xzf "${BUILD_DIR}/vscode-linux-arm64.tar.gz" -C "${VSCODE_DIR}" --strip-components=1

echo "Extracting Windsurf server..."
mkdir -p "${WINDSURF_SERVER_DIR}"
tar -xzf "${BUILD_DIR}/${WINDSURF_SERVER_ARCHIVE_NAME}" -C "${WINDSURF_SERVER_DIR}" --strip-components=1

# Build Windsurf
echo "Building Windsurf..."
mkdir -p "${FINAL_DIR}"
cp -r "${VSCODE_DIR}/." "${FINAL_DIR}"

# Overwrite with Windsurf's bin directory to get windsurf-cli
rm -rf "${FINAL_DIR}/bin"
cp -r "${WINDSURF_SRC_DIR}/bin" "${FINAL_DIR}/"

# Rename the main executable
mv "${FINAL_DIR}/code" "${FINAL_DIR}/windsurf"

# Copy Windsurf-specific files
cp -R "${WINDSURF_SRC_DIR}/resources/app/out" "${FINAL_DIR}/resources/app/"
cp "${WINDSURF_SRC_DIR}/resources/app/package.json" "${FINAL_DIR}/resources/app/"
cp "${WINDSURF_SRC_DIR}/resources/app/product.json" "${FINAL_DIR}/resources/app/"
cp -R "${WINDSURF_SRC_DIR}/resources/app/extensions/"* "${FINAL_DIR}/resources/app/extensions/"
cp "${WINDSURF_SRC_DIR}/resources/app/resources/linux/code.png" "${FINAL_DIR}/resources/app/resources/linux/code.png"

# Copy language server and fd from the Windsurf server archive, and make them executable
BIN_DEST_DIR="${FINAL_DIR}/resources/app/extensions/windsurf/bin"
mkdir -p "${BIN_DEST_DIR}"
cp "${WINDSURF_SERVER_DIR}/extensions/windsurf/bin/language_server_linux_arm" "${BIN_DEST_DIR}/language_server_linux_arm"
cp "${WINDSURF_SERVER_DIR}/extensions/windsurf/bin/fd" "${BIN_DEST_DIR}/fd"
chmod +x "${BIN_DEST_DIR}/language_server_linux_arm"
chmod +x "${BIN_DEST_DIR}/fd"

echo "Build complete!"
echo "Windsurf for Linux ARM64 is available at: ${FINAL_DIR}"

# Create final tarball
echo "Creating final tarball..."
ARTIFACT_NAME="windsurf_${WINDSURF_VERSION}_linux_arm64.tar.gz"
(cd "${OUTPUT_DIR}" && tar -czf "../../${ARTIFACT_NAME}" "$(basename "${FINAL_DIR}")")

echo "Build complete! Find the artifact at ./${ARTIFACT_NAME}"
