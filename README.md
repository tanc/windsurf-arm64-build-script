# Windsurf ARM64 Build Script

This script automates the download and packaging of a Windsurf build compatible with Linux ARM64 systems. It discovers the latest Windsurf release, reuses its metadata, and combines:

- The official Windsurf Linux x64 archive (for metadata and resources)
- The matching VS Code Linux ARM64 build (for core binaries)
- The Windsurf server Linux ARM64 archive (for `fd` and the language server)

into a single Windsurf Linux ARM64 tarball.

## Prerequisites

- Docker (must be running)
- `bash`
- `wget`
- `curl`
- `tar`

## Usage

To build the Windsurf application, run:

```bash
./windsurf-build.sh
```

The script will create a `build/` directory for intermediate files and generate a final application tarball (e.g. `windsurf_1.12.33_linux_arm64.tar.gz`) in the repository root.

### Skipping Downloads

If you have already run the script and want to rebuild the package using the previously downloaded files, you can use the `--no-redownload` flag:

```bash
./windsurf-build.sh --no-redownload
```

This will skip all download steps and use the existing files in the `build/` directory.

## How it Works

The script performs the following steps:

1.  **Discover Windsurf Source URL**: A Playwright-based scraper running in a Docker container automatically navigates to the Windsurf downloads page, finds the latest `Linux x64` download link, and captures the direct download URL.
2.  **Download and Extract Windsurf Source**: Downloads the Windsurf Linux x64 tarball and extracts it into the `build/` directory.
3.  **Discover Versions and Commit Hash**:
    - **Windsurf Version**: Extracted from the Linux x64 tarball filename.
    - **Commit Hash**: Extracted from the Windsurf Linux x64 download URL.
    - **VS Code Version**: Extracted from the Windsurf source `package.json`.
4.  **Download ARM64 Artifacts**:
    - The matching **VS Code Linux ARM64** build using `VSCODE_VERSION`.
    - The **Windsurf server Linux ARM64** archive using `WINDSURF_VERSION` and the commit hash. This archive contains the ARM64 `fd` binary and language server.
5.  **Package Application**:
    - Use VS Code Linux ARM64 as the base application.
    - Overlay Windsurf resources and extensions from the extracted Windsurf source.
    - Copy `fd` and the language server from the Windsurf server ARM64 archive into the Windsurf extension `bin` directory.
    - Rename the binary and package the result into a final `windsurf_<version>_linux_arm64.tar.gz` tarball.
