# Windsurf ARM64 Build Script

This script fully automates the download and packaging of a Windsurf version compatible with Linux ARM64 systems. It dynamically discovers all required versions and URLs, ensuring you always build against the latest available components without any manual intervention.

## Prerequisites

- Docker (must be running)
- `bash`
- `wget`
- `curl`
- `tar`

## Usage

To build the Windsurf application, simply execute the script:

```bash
./windsurf-build.sh
```

The script will create a `build/` directory for intermediate files and generate the final application tarball (e.g., `windsurf_1.10.5_linux_arm64.tar.gz`) in the root directory.

### Skipping Downloads

If you have already run the script and want to rebuild the package using the previously downloaded files, you can use the `--no-redownload` flag:

```bash
./windsurf-build.sh --no-redownload
```

This will skip all download steps and use the existing files in the `build/` directory.

## How it Works

The script performs the following steps:

1.  **Discover Windsurf Source URL**: A Playwright-based scraper running in a Docker container automatically navigates to the Windsurf releases page, finds the latest `Linux x64` download link, and captures the direct download URL.
2.  **Download and Extract Windsurf**: Downloads the source tarball and extracts it into the `build/` directory.
3.  **Discover Component Versions**:
    *   **Windsurf Version**: Extracted from the downloaded tarball's filename.
    *   **VS Code Version**: Extracted from a `product.json` file within the Windsurf source.
    *   **Language Server Version**: Extracted from a minified JavaScript file within the Windsurf extension source.
    *   **`fd` Version**: The `fd` binary included in the Windsurf source is copied into a minimal Docker container and executed with `--version` to dynamically determine its version.
4.  **Download ARM64 Dependencies**: Using the discovered versions, the script constructs the correct download URLs and fetches the ARM64-compatible versions of:
    *   VS Code
    *   The language server
    *   The `fd` utility
5.  **Package Application**: Assembles the final application by copying the base Windsurf files and replacing the `x86-64` language server and `fd` binaries with their `arm64` counterparts. The final application is then packaged into a single tarball.
