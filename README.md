# Spice Up Your Spotify on Arch Linux: The Ultimate Spicetify Installer (Flatpak Edition)

[![Script Version](https://img.shields.io/badge/Script%20Version-v2.2.2-success?style=for-the-badge&logo=bash)](./spicetify.sh)
[![GitHub Stars](https://img.shields.io/github/stars/boudywho/spicetify-arch-installation-guide?style=for-the-badge&logo=github&label=Star%20Me!)](https://github.com/boudywho/spicetify-arch-installation-guide/stargazers)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](./LICENSE)
<!-- Optional: Add a GIF of the script in action here if you make one! -->

**This script was a true labor of love (and quite a challenge!) to perfect.** Countless hours went into debugging tricky edge cases with Flatpak, Spicetify's internals, and shell scripting quirks to make it as robust and user-friendly as possible. If you find it helpful, **a simple ⭐ star on GitHub would mean the world and motivate further development!**

Tired of the default Spotify look? This guide and its powerful automation script will help you install and configure **Spicetify** on your Arch Linux system using the Flatpak version of Spotify, unlocking a world of customization!

## ✨ Features of the `spicetify.sh` Installer Script

*   **Fully Automated**: From dependency checks to permission handling and Spicetify configuration.
*   **Robust Path Detection**: Intelligently finds your Spotify Flatpak installation, whether system-wide or user-specific.
*   **Idempotent**: Safe to re-run; it handles existing installations gracefully.
*   **Interactive & User-Friendly**: Clear, color-coded output guides you through the process.
*   **Marketplace Included**: Prompts to install the Spicetify Marketplace for easy theme and extension management.
*   **Error Handling**: Provides informative messages if issues arise.
*   **Modern Bash Practices**: Clean, maintainable, and efficient code.

## 🚀 Quick Install via Automated Script (Recommended)

This script is the recommended way to install Spicetify. It has been significantly improved and tested.

**Prerequisites:**
*   An Arch-based Linux distribution.
*   Spotify installed as a Flatpak from Flathub: `flatpak install flathub com.spotify.Client`
*   Basic familiarity with the terminal.

**Installation Steps:**

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/boudywho/spicetify-arch-installation-guide.git
    cd spicetify-arch-installation-guide
    ```

2.  **Make the Script Executable:**
    ```bash
    chmod +x spicetify.sh
    ```

3.  **Run the Script:**
    ```bash
    ./spicetify.sh
    ```
    *   The script will guide you through the necessary steps.
    *   It will ask for your `sudo` password for package installation (like `curl`, `gawk` if missing) and for setting permissions on Flatpak directories.
    *   When the Spicetify CLI installer runs, it will ask if you want to install the **Spicetify Marketplace**. It's highly recommended to type `y` (yes) for this.

4.  **Restart Spotify:**
    Once the script completes, close and reopen Spotify to see the changes and access the Marketplace.

## 🛠️ Troubleshooting with the Script

*   **"prefs file not found" during Spicetify's own installer**: This is often normal if Spotify (Flatpak) hasn't been run recently or after a fresh install. The main script attempts to correct Spicetify's configuration *after* its installer runs. If issues persist with this error after the script finishes, ensure you run Spotify at least once and then re-run `./spicetify.sh`.
*   **Permission Issues**: The script attempts to set necessary permissions. If you still face permission-related errors from Spicetify, double-check the permissions on your Spotify Flatpak directory (usually under `/var/lib/flatpak/app/com.spotify.Client/...`).
*   **Other Issues**: If you encounter problems, please [open an issue](https://github.com/boudywho/spicetify-arch-installation-guide/issues) on the repository. Include the **full terminal output** from the script execution and the version of the script you are using (e.g., v2.2.2).

## 🧐 Manual Installation (For Reference or Advanced Users)

If you prefer a manual approach or want to understand the steps involved, here's a condensed guide. The automated script performs these steps more robustly.

1.  **Install Prerequisites:**
    ```bash
    sudo pacman -S curl gawk --noconfirm
    ```

2.  **Install Spicetify CLI & Marketplace:**
    The official Spicetify installer usually handles both.
    ```bash
    curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh | bash
    # Follow prompts, especially for Marketplace installation.
    ```
    Ensure `~/.spicetify` or `~/.local/bin` is in your PATH.

3.  **Locate Spotify Flatpak Paths:**
    *   **Spotify Installation Path**:
        ```bash
        # For system install (most common)
        sudo flatpak info --show-location com.spotify.Client
        # For user install
        # flatpak info --show-location com.spotify.Client
        ```
        The `spotify_path` for Spicetify config will be this path + `/files/extra/share/spotify` or `/files/share/spotify`.
        *Example:* `/var/lib/flatpak/app/com.spotify.Client/x86_64/stable/LONG_HASH_HERE/files/extra/share/spotify`
    *   **Spotify Preferences Path**:
        This is typically `~/.var/app/com.spotify.Client/config/spotify/prefs`.
        *Note: This file is created after Spotify runs at least once.*

4.  **Configure Spicetify (`~/.config/spicetify/config-xpui.ini`):**
    Manually edit this file or use `spicetify config` commands:
    ```bash
    # Example (replace paths with your actual found paths)
    spicetify config spotify_path /your/actual/spotify_path
    spicetify config prefs_path /your/actual/prefs_path
    ```
    Ensure Spotify has been run at least once for `prefs_path` to be valid.

5.  **Grant Permissions:**
    Replace `<Spotify App Files Path>` with the path derived in step 3 (e.g., `/var/lib/flatpak/.../files/extra/share/spotify`).
    ```bash
    sudo chmod a+wr -R "<Spotify App Files Path>"
    # Specifically for the Apps subdirectory if it exists or will be created:
    sudo chmod a+wr -R "<Spotify App Files Path>/Apps"
    ```

6.  **Apply Spicetify:**
    It's good practice to restore first if you've tried before, then backup and apply.
    ```bash
    spicetify restore
    spicetify backup apply
    spicetify apply
    ```

## 🎨 Customization
Once Spicetify is installed and applied:
*   Use the **Marketplace** (usually a new item in Spotify's left sidebar) to browse and install themes, extensions, and custom apps.
*   Use the Spicetify CLI for more advanced configuration:
    *   `spicetify config current_theme MyThemeName`
    *   `spicetify --help` for all commands.

## 📜 Changelog (Automated Script `spicetify.sh`)

**v2.2.2 (Current) - Fine-tuning Output Details**
*   Corrected ANSI escape sequence interaction for `task_detail` calls in the final "Next Steps & Tips" section to ensure intended text styling (dimmed labels, specifically styled commands).

**v2.2.1 - Output Polish Fix**
*   Fixed specific `task_detail` output lines in the final summary to correctly display styled command examples.
*   Adjusted `grep` for config verification in `configure_and_backup_spicetify` to use simpler fixed-string matching (`grep -Fq`) which proved more reliable with path strings.

**v2.2.0 - Major Output Makeover**
*   **Complete overhaul of script output**:
    *   Introduced new dedicated functions for different message types: `script_title`, `section_header`, `task_running`, `task_detail`, `task_info`, `task_success`, `task_warning`, `task_error_exit`.
    *   Refined color scheme for better visual hierarchy and clarity (Spicetify Pink for titles, Blue for sections, Cyan for tasks, etc.).
    *   Improved formatting with visual separators, indentation, and consistent symbols.
*   Enhanced `confirm` function with customizable prompt characters and default answers.
*   Added spacing around external script outputs (like Spicetify's own installer) for better readability.

**v2.1.9 - Final Polish for Robustness**
*   Corrected `grep` verification in `configure_and_backup_spicetify` to use more robust extended regex for checking paths in the config file, handling variable spacing around `=`.

**v2.1.8 - Idempotency and Reliability**
*   **Made script fully idempotent for first-run success!**
*   Modified `configure_and_backup_spicetify`:
    *   Runs `spicetify restore` before `spicetify backup apply` to ensure Spotify is in a clean state, preventing "backup already exists" errors on re-runs.
    *   Improved `sed` commands to use `|` as a delimiter for safer path handling.
    *   Corrected `grep` verification for config file paths to use exact string matching (`-Fq`).
*   Renamed `configure_spicetify` to `configure_and_backup_spicetify` and `apply_spicetify_changes` to `apply_spicetify_theme_and_extensions` for clarity.

**v2.1.7 - Sudo Check Fix**
*   Corrected a syntax error in the `check_sudo` function that prevented the script from running. Reverted to a more robust `sudo -v` and `sudo true` check.
*   Added basic path escaping for `sed` replacement strings in `configure_spicetify`.

**v2.1.6 - The Breakthrough: Forced Configuration**
*   **Major change in `configure_spicetify`**:
    *   Ensures base `config-xpui.ini` exists, generating a minimal one if necessary.
    *   **Crucially, uses `sed` to forcefully write the correct `prefs_path` and `spotify_path` into `config-xpui.ini` *before* calling `spicetify backup apply`**. This bypasses Spicetify's own problematic path detection at that stage.
*   This version marked the point where the script started working reliably for core patching.

**v2.1.5 - Direct Path Retrieval with `--show-location`**
*   **Solved Flatpak path detection!**
*   Modified `get_spotify_flatpak_paths` to primarily use `sudo flatpak info --show-location <APP_ID>`. This directly outputs the path, proving far more reliable than parsing the full `flatpak info` output.
*   Kept older parsing methods as fallbacks.

**v2.1.4 - Debugging Flatpak Info**
*   Enhanced `get_spotify_flatpak_paths` to run `flatpak info` with `sudo` first, as system-wide Flatpak installations often only show the "Location:" field when queried by root.
*   Added more verbose debugging for `flatpak info` output.

**v2.1.3 - Enhanced Path Parsing & Debugging**
*   Significantly improved `get_spotify_flatpak_paths`:
    *   Added printing of raw `flatpak info` output for easier debugging.
    *   Switched to a more robust `gawk` method for parsing the "Location:" line.
    *   Included a `grep`/`sed` fallback if `gawk` failed.
    *   Added check to ensure `gawk` is installed.

**v2.1.2 - Interactive Installer Fix**
*   Corrected the Spicetify CLI installation call (`bash <(curl ...)`) to allow its installer script to run fully interactively (e.g., for Marketplace prompts) by not redirecting its stdout/stderr.

**v2.1.1 - Installer Robustness**
*   Fixed `install_spicetify_cli` to correctly handle cases where Spicetify's `install.sh` might exit with an error due to its own initial config checks (like "prefs not found") even if the binary was installed. The script now verifies binary installation independently.
*   Removed redundant manual Marketplace installation as Spicetify's main installer handles it.

**v2.0.0 -> v2.1.0 - Initial Major Refactor & Debugging**
*   The script underwent a significant transformation from its original simpler form.
*   Introduced modular functions, robust error handling (`error_exit`, `command_exists`), colorized/styled output (`cecho`, `header`, etc.), and modern Bash practices.
*   Focused on correcting the order of operations (permissions before `backup apply`).
*   Improved Flatpak path detection using `flatpak info` and `awk`.
*   Switched from manual `awk` editing of `config-xpui.ini` to using `spicetify config` commands.
*   Addressed various bugs related to PATH, command execution, and Spicetify's interaction with Flatpak.

**Original Script (Pre-v2.0.0)**
*   A simpler, more direct sequence of commands.
*   Basic `echo` for output.
*   Manual `awk` for `config-xpui.ini` modification.
*   Less robust error handling and path detection.
*   *This collaborative overhaul has dramatically improved reliability, user experience, and maintainability.*

---
