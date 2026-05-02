#!/usr/bin/env bash
#
# Spicetify Universal Setup Script
# Version 3.0.6
# Cross-distro compatible (Arch, Debian, Ubuntu, Fedora, openSUSE, Alpine, more)
# Supports bash, zsh, fish.
# Automatically detects distro & package manager, sets up Flatpak Spotify + Spicetify.
#

# =============================================================================
# Strict Mode & Global Flags
# =============================================================================

set -eEuo pipefail

DEBUG="${DEBUG:-0}"
DRY_RUN="${DRY_RUN:-0}"
VERBOSE="${VERBOSE:-0}"

if [[ "${DEBUG}" == "1" ]]; then
    set -x
fi

# =============================================================================
# Constants
# =============================================================================

readonly SCRIPT_VERSION="3.0.6"
readonly SPOTIFY_FLATPAK_ID="com.spotify.Client"
readonly INSTALLER_URL="${SPICETIFY_INSTALL_URL:-https://raw.githubusercontent.com/spicetify/cli/main/install.sh}"
readonly INSTALLER_SHA256="${SPICETIFY_INSTALLER_SHA256:-}"
readonly CONFIG_FILE="${CONFIG_FILE:-${HOME}/.config/spicetify-setup/setup.conf}"
readonly SPICETIFY_CONFIG_DIR="${HOME}/.config/spicetify"
readonly SPICETIFY_CLI_DIR="${HOME}/.spicetify"

# =============================================================================
# Globals (set during execution)
# =============================================================================

declare SPOTIFY_FLATPAK_LOCATION=""
declare SPOTIFY_APP_FILES_PATH=""
declare SPOTIFY_PREFS_PATH=""
declare PKG_MANAGER=""
declare DISTRO_ID=""
declare -a _TMP_FILES=()

# =============================================================================
# Temp File Cleanup
# =============================================================================

trap '_cleanup_tmp' EXIT INT TERM

_cleanup_tmp() {
    local f
    for f in "${_TMP_FILES[@]:-}"; do
        rm -rf -- "$f" 2>/dev/null || true
    done
}

_mktemp() {
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/spicetify-$$-XXXXXX") || return 1
    _TMP_FILES+=("$tmp")
    printf '%s' "$tmp"
}

# =============================================================================
# Color Support Detection
# =============================================================================

_color_support() {
    case "${TERM:-}" in
        dumb|unknown|''|native)
            return 1
            ;;
    esac
    return 0
}

# =============================================================================
# Colors
# =============================================================================

_color() {
    _color_support || return 0
    printf '%s' "$1"
}

readonly COLOR_RESET="$(_color $'\x1b[0m')"
readonly COLOR_RED="$(_color $'\x1b[0;31m')"
readonly COLOR_GREEN="$(_color $'\x1b[0;32m')"
readonly COLOR_YELLOW="$(_color $'\x1b[0;33m')"
readonly COLOR_BLUE="$(_color $'\x1b[0;34m')"
readonly COLOR_CYAN="$(_color $'\x1b[0;36m')"
readonly COLOR_SPICETIFY="$(_color $'\x1b[38;5;199m')"
readonly BOLD="$(_color $'\x1b[1m')"
readonly DIM="$(_color $'\x1b[2m')"

# =============================================================================
# Logging & UI Helpers
# =============================================================================

script_title() {
    printf '\n%s%s%s\n' "${COLOR_SPICETIFY}" "${BOLD}" "$1" "${COLOR_RESET}"
    printf '%s%s%s\n' "${COLOR_BLUE}" "${DIM}" "───────────────────────────────────────────────────" "${COLOR_RESET}"
}

section_header() {
    printf '\n%s%s==> %s%s\n' "${COLOR_BLUE}" "${BOLD}" "$1" "${COLOR_RESET}"
}

task_running() {
    printf '  %s↪ %s%s\n' "${COLOR_CYAN}" "$1" "${COLOR_RESET}"
}

task_detail() {
    printf '    %s› %s%s\n' "${DIM}" "$1" "${COLOR_RESET}"
}

task_info() {
    printf '  %sⓘ %s%s\n' "${COLOR_CYAN}" "$1" "${COLOR_RESET}"
}

task_success() {
    printf '  %s✓ %s%s\n' "${COLOR_GREEN}" "$1" "${COLOR_RESET}"
}

task_warning() {
    printf '  %s⚠ %s%s\n' "${COLOR_YELLOW}" "$1" "${COLOR_RESET}"
}

task_error_exit() {
    printf '  %s%s✗ ERROR: %s%s\n' "${COLOR_RED}" "${BOLD}" "$1" "${COLOR_RESET}" >&2
    exit 1
}

log_debug() {
    [[ "${DEBUG:-0}" == "1" ]] || return 0
    printf '  %s[DEBUG]%s %s\n' "${DIM}" "${COLOR_RESET}" "$1" >&2
}

# =============================================================================
# Internal Helpers
# =============================================================================

_is_interactive() {
    [[ -t 0 && -t 1 ]] && tty &>/dev/null
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# =============================================================================
# Distro & Package Manager Detection
# =============================================================================

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        DISTRO_ID=$(grep -m1 '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]') || DISTRO_ID="unknown"
    else
        DISTRO_ID="unknown"
    fi
    printf '%s' "${DISTRO_ID}"
}

detect_package_manager() {
    local os_id os_like combined

    if [[ -f /etc/os-release ]]; then
        os_id=$(set +e; . /etc/os-release 2>/dev/null; printf '%s' "$ID")
        os_like=$(set +e; . /etc/os-release 2>/dev/null; printf '%s' "${ID_LIKE:-}")
        combined="${os_id} ${os_like}"

        case "$combined" in
            *arch*|*artix*|*endeavouros*|*manjaro*|*garuda*|*cachyos*)
                printf 'pacman'; return ;;
            *debian*|*ubuntu*|*mint*|*pop*|*zorin*|*elementary*|*kali*)
                printf 'apt'; return ;;
            *fedora*|*rhel*|*centos*|*rocky*|*alma*|*amzn*|*nobara*)
                command_exists dnf && { printf 'dnf'; return; }
                printf 'yum'; return ;;
            *suse*|*opensuse*|*gecko*)
                printf 'zypper'; return ;;
            *alpine*)
                printf 'apk'; return ;;
            *gentoo*)
                printf 'emerge'; return ;;
            *void*)
                printf 'xbps'; return ;;
            *solus*)
                printf 'eopkg'; return ;;
            *clear*)
                printf 'swupd'; return ;;
            *nixos*)
                printf 'nix'; return ;;
        esac
    fi

    command_exists pacman       && { printf 'pacman';  return; }
    command_exists apt-get      && { printf 'apt';     return; }
    command_exists dnf          && { printf 'dnf';     return; }
    command_exists yum          && { printf 'yum';     return; }
    command_exists zypper       && { printf 'zypper';  return; }
    command_exists apk          && { printf 'apk';     return; }
    command_exists emerge       && { printf 'emerge';  return; }
    command_exists xbps-install && { printf 'xbps';    return; }
    command_exists eopkg        && { printf 'eopkg';   return; }
    command_exists swupd        && { printf 'swupd';   return; }
    command_exists nix-env      && { printf 'nix';     return; }

    printf 'unknown'
}

# =============================================================================
# Confirmation Prompt
# =============================================================================

confirm() {
    local prompt="${1:-Are you sure?}"
    local char_prompt="${2:-y/N}"
    local default_ans="${3:-N}"
    local response

    if ! _is_interactive; then
        case "${default_ans,,}" in
            y|yes|1) return 0 ;;
            *)       return 1 ;;
        esac
    fi

    while true; do
        if [[ -t 0 ]]; then
            read -r -p "$(printf '  %s? %s [%s]: %s' "${COLOR_YELLOW}" "${prompt}" "${char_prompt}" "${COLOR_RESET}")" response < /dev/tty
        else
            read -r -p "$(printf '  %s? %s [%s]: %s' "${COLOR_YELLOW}" "${prompt}" "${char_prompt}" "${COLOR_RESET}")" response
        fi
        response="${response:-${default_ans}}"
        case "${response}" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) printf '  %sPlease answer '\''y'\'' or '\''n'\''.%s\n' "${COLOR_RED}" "${COLOR_RESET}" ;;
        esac
    done
}

# =============================================================================
# Dry-Run Execution Wrapper
# =============================================================================

dry_run_exec() {
    if [[ "${DRY_RUN}" == "1" ]]; then
        task_info "[DRY-RUN] Would execute: $*"
        return 0
    fi
    "$@"
}

# =============================================================================
# Process Management (Auto-Kill Spotify)
# =============================================================================

spotify_is_running() {
    flatpak ps 2>/dev/null | grep -Fqx "${SPOTIFY_FLATPAK_ID}"
}

kill_spotify() {
    local max_attempts=3
    local attempt=1

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if ! spotify_is_running; then
            task_success "Spotify is not running."
            return 0
        fi

        if [[ ${attempt} -eq 1 ]]; then
            task_running "Spotify is running. Closing it automatically..."
        else
            task_warning "Attempt ${attempt}/${max_attempts}..."
        fi

        dry_run_exec flatpak kill "${SPOTIFY_FLATPAK_ID}" 2>/dev/null || \
            dry_run_exec killall -9 spotify 2>/dev/null || true

        sleep 2

        if ! spotify_is_running; then
            task_success "Spotify closed successfully."
            return 0
        fi
        attempt=$((attempt + 1))
    done

    task_warning "Could not close Spotify after ${max_attempts} attempts."
    if confirm "Please close Spotify manually. Is it closed now?" "Y/n" "Y"; then
        return 0
    fi
    task_error_exit "Aborted. Please close Spotify and re-run."
}

# =============================================================================
# Sudo Handling
# =============================================================================

check_sudo() {
    if [[ "${EUID}" -eq 0 && -n "${SUDO_USER}" ]]; then
        task_error_exit "Please run this script as your normal user, NOT with sudo. The script will request sudo automatically when needed."
    fi

    if [[ "${EUID}" -ne 0 ]]; then
        if ! sudo -n true 2>/dev/null; then
            printf '  %sⓘ Sudo requires a password. Please enter it when prompted.%s\n' "${COLOR_YELLOW}" "${COLOR_RESET}"
            if ! sudo -v; then
                task_error_exit "Sudo privileges required and could not be obtained."
            fi
        fi
        if ! sudo true; then
            task_error_exit "Sudo check failed. Cannot execute commands with sudo."
        fi
        task_success "Sudo privileges verified."
    else
        task_success "Running as root."
    fi
}

# =============================================================================
# Package Installation (distro-agnostic)
# =============================================================================

_pkg_refresh_cache() {
    local mgr="$1"
    case "${mgr}" in
        pacman) dry_run_exec sudo pacman -Sy --noconfirm ;;
        apt)    dry_run_exec sudo apt-get update -qq ;;
        dnf|yum|zypper|apk|emerge|xbps|eopkg|swupd|nix)
            ;;
    esac
}

install_packages() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    local missing=()
    local pkg

    for pkg in "$@"; do
        if ! command_exists "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi

    section_header "Installing ${missing[*]}"

    for pkg in "${missing[@]}"; do
        if command_exists "$pkg"; then
            continue
        fi

        task_running "Installing '${pkg}' via ${pkg_manager}..."

        _pkg_refresh_cache "${pkg_manager}" || true

        local status=0
        case "${pkg_manager}" in
            pacman)   dry_run_exec sudo pacman -S --noconfirm -- "$pkg"             || status=$? ;;
            apt)      dry_run_exec sudo apt-get install -y -- "$pkg"                || status=$? ;;
            dnf)      dry_run_exec sudo dnf install -y -- "$pkg"                    || status=$? ;;
            yum)      dry_run_exec sudo yum install -y -- "$pkg"                    || status=$? ;;
            zypper)   dry_run_exec sudo zypper --non-interactive install -- "$pkg"  || status=$? ;;
            apk)      dry_run_exec sudo apk add -- "$pkg"                           || status=$? ;;
            emerge)   dry_run_exec sudo emerge --noreplace -- "$pkg"                 || status=$? ;;
            xbps)     dry_run_exec sudo xbps-install -y -- "$pkg"                   || status=$? ;;
            eopkg)    dry_run_exec sudo eopkg install -y -- "$pkg"                  || status=$? ;;
            swupd)    dry_run_exec sudo swupd bundle-add -- "$pkg"                  || status=$? ;;
            nix)      dry_run_exec nix-env -iA "nixpkgs.${pkg}"                    || status=$? ;;
            *)
                task_error_exit "Unknown package manager '${pkg_manager}'. Please install '${pkg}' manually."
                ;;
        esac

        if [[ ${status} -ne 0 ]]; then
            task_error_exit "Failed to install ${pkg}. Please install it manually and re-run."
        fi
        task_success "${pkg} installed."
    done
}

# =============================================================================
# Flatpak Path Detection
# =============================================================================

get_spotify_flatpak_paths() {
    section_header "Locating Spotify Flatpak"

    if ! command_exists flatpak; then
        task_error_exit "Flatpak is not installed. Please install Flatpak and Spotify first."
    fi

    task_running "Detecting Spotify Flatpak location (user install first)..."
    SPOTIFY_FLATPAK_LOCATION=$(flatpak info --show-location "${SPOTIFY_FLATPAK_ID}" 2>/dev/null || true)

    if [[ -n "${SPOTIFY_FLATPAK_LOCATION}" && -d "${SPOTIFY_FLATPAK_LOCATION}" ]]; then
        task_success "Found user Flatpak: ${SPOTIFY_FLATPAK_LOCATION}"
    else
        task_running "Trying system-wide installation..."
        SPOTIFY_FLATPAK_LOCATION=$(sudo flatpak info --show-location "${SPOTIFY_FLATPAK_ID}" 2>/dev/null || true)

        if [[ -n "${SPOTIFY_FLATPAK_LOCATION}" && -d "${SPOTIFY_FLATPAK_LOCATION}" ]]; then
            task_success "Found system-wide Flatpak: ${SPOTIFY_FLATPAK_LOCATION}"
        else
            task_error_exit "Could not locate Spotify Flatpak. Is it installed? Run: flatpak install flathub com.spotify.Client"
            task_error_exit "Have you run Spotify at least once?  flatpak run com.spotify.Client"
        fi
    fi

    SPOTIFY_APP_FILES_PATH="${SPOTIFY_FLATPAK_LOCATION}/files/extra/share/spotify"
    local alt_app_files_path="${SPOTIFY_FLATPAK_LOCATION}/files/share/spotify"

    if [[ -d "${SPOTIFY_APP_FILES_PATH}" ]]; then
        task_detail "Using: ${SPOTIFY_APP_FILES_PATH}"
    elif [[ -d "${alt_app_files_path}" ]]; then
        SPOTIFY_APP_FILES_PATH="${alt_app_files_path}"
        task_detail "Using alternative: ${SPOTIFY_APP_FILES_PATH}"
    else
        task_detail "Target directory will be created if needed: ${SPOTIFY_APP_FILES_PATH}"
    fi

    SPOTIFY_PREFS_PATH="${HOME}/.var/app/${SPOTIFY_FLATPAK_ID}/config/spotify/prefs"

    if [[ -f "${SPOTIFY_PREFS_PATH}" ]]; then
        task_success "Prefs file found: ${SPOTIFY_PREFS_PATH}"
    else
        task_warning "Prefs file not found: ${SPOTIFY_PREFS_PATH}"
        task_detail "Run Spotify (Flatpak) at least once to generate it."
    fi

    export SPOTIFY_APP_FILES_PATH SPOTIFY_PREFS_PATH
}

# =============================================================================
# Grant Permissions
# =============================================================================

grant_permissions() {
    section_header "Granting Filesystem Permissions"

    if [[ -z "${SPOTIFY_APP_FILES_PATH}" ]]; then
        task_warning "Spotify path not set. Skipping."
        return 1
    fi

    if [[ ! -d "${SPOTIFY_APP_FILES_PATH}" ]]; then
        task_running "Creating directory: ${SPOTIFY_APP_FILES_PATH}"
        dry_run_exec sudo mkdir -p "${SPOTIFY_APP_FILES_PATH}" || task_error_exit "Failed to create directory."
        task_success "Directory created."
    fi

    task_running "Setting permissions on ${SPOTIFY_APP_FILES_PATH}..."
    dry_run_exec sudo chmod a+wr "${SPOTIFY_APP_FILES_PATH}" || task_error_exit "chmod failed."

    local apps_dir="${SPOTIFY_APP_FILES_PATH}/Apps"
    if [[ -d "${apps_dir}" ]]; then
        dry_run_exec sudo chmod -R a+wr "${apps_dir}"
        task_success "Permissions set (including Apps folder)."
    else
        task_detail "Apps folder will be created by Spicetify if needed."
    fi

    return 0
}

# =============================================================================
# Download with Integrity Check
# =============================================================================

_download_file() {
    local url="$1"
    local dest="$2"
    local sha256_expected="${3:-}"

    log_debug "Downloading: ${url} -> ${dest}"

    if ! curl -fsSL "${url}" -o "${dest}"; then
        return 1
    fi

    if [[ -n "${sha256_expected}" ]]; then
        local sha256_actual
        sha256_actual=$(sha256sum "${dest}" | cut -d' ' -f1)
        if [[ "${sha256_actual}" != "${sha256_expected}" ]]; then
            rm -f "${dest}"
            printf 'ERROR: SHA256 mismatch. Expected: %s Got: %s\n' "${sha256_expected}" "${sha256_actual}" >&2
            return 1
        fi
        log_debug "SHA256 verified: ${sha256_actual}"
    fi

    return 0
}

# =============================================================================
# Install Spicetify CLI
# =============================================================================

install_spicetify_cli() {
    section_header "Installing Spicetify CLI"

    if [[ -d "${SPICETIFY_CLI_DIR}" ]]; then
        export PATH="${SPICETIFY_CLI_DIR}:${PATH}"
    fi

    if command_exists spicetify; then
        task_info "Spicetify CLI is installed: $(spicetify --version 2>/dev/null || echo 'unknown version')"
        if ! confirm "Spicetify is already installed. Re-install / update it?" "y/N" "N"; then
            task_success "Skipping Spicetify installation."
            return 0
        fi
        task_running "Proceeding with update..."
    fi

    task_running "Downloading official Spicetify installer..."

    local tmp_installer
    tmp_installer=$(_mktemp) || task_error_exit "Failed to create temp file."

    if ! _download_file "${INSTALLER_URL}" "${tmp_installer}" "${INSTALLER_SHA256}"; then
        task_error_exit "Failed to download Spicetify installer. Check your internet connection."
    fi

    chmod 755 "${tmp_installer}"

    task_running "Running installer script..."

    if ! dry_run_exec bash "${tmp_installer}"; then
        task_warning "Installer exited with an error (expected if you chose Marketplace). Continuing..."
    else
        task_success "Spicetify CLI installed successfully."
    fi

    if [[ -d "${SPICETIFY_CLI_DIR}" ]]; then
        export PATH="${SPICETIFY_CLI_DIR}:${PATH}"
    fi

    if ! command_exists spicetify; then
        task_error_exit "Spicetify command not found after installation."
    fi

    task_success "Spicetify is ready: $(spicetify --version 2>/dev/null)"
}

# =============================================================================
# Make PATH Persistent
# =============================================================================

make_path_persistent() {
    section_header "Making Spicetify Available in New Terminals"

    local shell_name
    shell_name=$(basename "$(readlink /proc/$$/exe 2>/dev/null || echo "${SHELL}")")

    local rc_file=""
    local export_line=""

    case "${shell_name}" in
        bash)
            rc_file="${HOME}/.bashrc"
            export_line='export PATH="$HOME/.spicetify:$PATH"'
            ;;
        zsh)
            rc_file="${HOME}/.zshrc"
            export_line='export PATH="$HOME/.spicetify:$PATH"'
            ;;
        fish)
            rc_file="${HOME}/.config/fish/config.fish"
            export_line='fish_add_path "$HOME/.spicetify"'
            ;;
        *)
            task_warning "Unknown shell: ${shell_name}"
            task_detail "Please manually add this line to your shell config:"
            task_detail "export PATH=\"\$HOME/.spicetify:\$PATH\""
            return 0
            ;;
    esac

    if [[ -f "${rc_file}" ]] && grep -q "\.spicetify" "${rc_file}" 2>/dev/null; then
        task_success "PATH already configured in ${rc_file}"
        return 0
    fi

    if confirm "Add Spicetify to your PATH permanently in ${rc_file}?" "Y/n" "Y"; then
        mkdir -p "$(dirname "${rc_file}")"

        if [[ "${shell_name}" == "fish" ]]; then
            printf '\n# Spicetify\nfish_add_path "$HOME/.spicetify"\n' >> "${rc_file}"
        else
            printf '\n# Spicetify\nexport PATH="$HOME/.spicetify:$PATH"\n' >> "${rc_file}"
        fi
        task_success "Added to ${rc_file}. Restart your terminal or run: source ${rc_file}"
    else
        task_warning "Skipped. You can add it manually later."
    fi
}

# =============================================================================
# Configure Spicetify
# =============================================================================

configure_spicetify() {
    section_header "Configuring Spicetify for Flatpak Spotify"

    kill_spotify

    if ! command_exists spicetify; then
        task_error_exit "Spicetify not found."
    fi

    task_running "Ensuring Spicetify config exists..."
    if [[ ! -f "${SPICETIFY_CONFIG_DIR}/config-xpui.ini" ]]; then
        spicetify >/dev/null 2>&1 || true
        task_success "Config file generated."
    else
        task_success "Config already exists."
    fi

    if [[ -n "${SPOTIFY_APP_FILES_PATH}" ]]; then
        task_running "Setting spotify_path to ${SPOTIFY_APP_FILES_PATH}..."
        dry_run_exec spicetify config spotify_path "${SPOTIFY_APP_FILES_PATH}" || true
    fi

    if [[ -n "${SPOTIFY_PREFS_PATH}" && -f "${SPOTIFY_PREFS_PATH}" ]]; then
        task_running "Setting prefs_path to ${SPOTIFY_PREFS_PATH}..."
        dry_run_exec spicetify config prefs_path "${SPOTIFY_PREFS_PATH}" || true
    else
        task_warning "prefs_path not set (Spotify may not have been run yet)."
    fi

    spicetify config color_scheme "" >/dev/null 2>&1 || true
    spicetify config check_spicetify_upgrade 0 >/dev/null 2>&1 || true

    task_success "Configuration complete."
}

# =============================================================================
# Apply Patches
# =============================================================================

apply_patches() {
    section_header "Applying Spicetify Patches"

    kill_spotify

    task_running "Restoring Spotify to vanilla state (safe if already patched)..."
    spicetify restore 2>/dev/null || task_warning "No previous backup found (normal on first run)."

    kill_spotify

    task_running "Running 'spicetify backup apply'..."
    if dry_run_exec spicetify backup apply; then
        task_success "Backup & apply completed."
    else
        task_error_exit "'spicetify backup apply' failed. Check output above."
    fi
}

# =============================================================================
# Apply Theme
# =============================================================================

apply_theme() {
    section_header "Finalizing Setup"

    kill_spotify

    task_running "Running 'spicetify apply'..."
    if dry_run_exec spicetify apply; then
        task_success "Spicetify applied successfully!"
    else
        task_error_exit "spicetify apply failed."
    fi
}

# =============================================================================
# Uninstall / Cleanup Mode
# =============================================================================

uninstall_spicetify() {
    section_header "Uninstalling Spicetify"

    task_running "Restoring Spotify to vanilla state..."
    if command_exists spicetify; then
        spicetify restore 2>/dev/null || task_warning "No backup to restore."
    fi

    task_running "Removing Spicetify CLI..."
    rm -rf -- "${SPICETIFY_CLI_DIR}" 2>/dev/null || true
    rm -f -- "${HOME}/.local/bin/spicetify" 2>/dev/null || true

    task_running "Removing config..."
    rm -rf -- "${SPICETIFY_CONFIG_DIR}" 2>/dev/null || true

    task_running "Removing PATH entries from shell configs..."
    for rc in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.config/fish/config.fish"; do
        if [[ -f "${rc}" ]]; then
            grep -v '\.spicetify' "${rc}" > "${rc}.tmp" && mv -- "${rc}.tmp" "${rc}" || true
        fi
    done

    task_success "Spicetify has been uninstalled."
}

# =============================================================================
# Usage / Help
# =============================================================================

usage() {
    printf '%s\n' "Usage: $0 [OPTIONS]"
    printf '\n%s\n' "Spicetify Universal Setup v${SCRIPT_VERSION}"
    printf '\n%s\n' "Options:"
    printf '  %s\n' "-h, --help              Show this help message"
    printf '  %s\n' "-d, --debug             Enable debug mode (set -x)"
    printf '  %s\n' "-n, --dry-run           Show what would be done without executing"
    printf '  %s\n' "-u, --uninstall         Uninstall Spicetify and restore Spotify"
    printf '  %s\n' "-v, --version           Show version"
    printf '  %s\n' "-V, --verbose           Enable verbose output"
    printf '\n%s\n' "Environment variables:"
    printf '  %s\n' "  DEBUG=1                Enable debug output"
    printf '  %s\n' "  DRY_RUN=1              Dry-run mode"
    printf '  %s\n' "  VERBOSE=1              Enable verbose output"
    printf '  %s\n' "  SPICETIFY_INSTALL_URL=  Override installer URL"
    printf '  %s\n' "  SPICETIFY_INSTALLER_SHA256=  Expected SHA256 of installer"
}

# =============================================================================
# Argument Parsing
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--debug)
                DEBUG=1
                set -x
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=1
                task_info "Dry-run mode enabled."
                shift
                ;;
            -u|--uninstall)
                confirm "This will restore Spotify to vanilla and remove Spicetify. Continue?" || exit 0
                check_sudo
                uninstall_spicetify
                exit 0
                ;;
            -v|--version)
                printf '%s\n' "Spicetify Universal Setup v${SCRIPT_VERSION}"
                exit 0
                ;;
            -V|--verbose)
                VERBOSE=1
                shift
                ;;
            -*)
                printf 'Unknown option: %s\n' "$1" >&2
                usage
                exit 1
                ;;
            *)
                printf 'Unexpected argument: %s\n' "$1" >&2
                usage
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# Load Config File (optional)
# =============================================================================

load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        log_debug "Loading config from ${CONFIG_FILE}"
        if [[ -O "${CONFIG_FILE}" ]]; then
            case "$(stat -c '%a' "${CONFIG_FILE}" 2>/dev/null)" in
                [0-7][0-7][0-7])
                    source -- "${CONFIG_FILE}" 2>/dev/null || true
                    ;;
                *)
                    task_warning "Config file has insecure permissions. Skipping."
                    ;;
            esac
        else
            task_warning "Config file not owned by you. Skipping."
        fi
    fi
}

# =============================================================================
# Distro-Specific Hints
# =============================================================================

show_distro_hints() {
    local distro
    distro=$(detect_distro)

    case "${distro}" in
        alpine)
            task_info "On Alpine Linux:"
            task_detail "  1. Enable community repo in /etc/apk/repositories"
            task_detail "  2. flatpak may need kernel features not in BusyBox default"
            ;;
        arch)
            task_info "On Arch Linux:"
            task_detail "  Consider also: yay -S flatpak spotify"
            ;;
        debian|ubuntu)
            task_info "On ${distro}:"
            task_detail "  Flatpak may need: flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
            ;;
        fedora|rhel|centos)
            task_info "On ${distro}:"
            task_detail "  Flatpak: sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
            ;;
    esac
}

# =============================================================================
# Pre-flight Checks
# =============================================================================

preflight_checks() {
    section_header "Pre-flight Checks"

    PKG_MANAGER=$(detect_package_manager)
    DISTRO_ID=$(detect_distro)

    task_info "Distro: ${DISTRO_ID}"
    task_info "Package manager: ${PKG_MANAGER}"
    task_info "User: $(whoami)"
    task_info "Shell: ${SHELL}"
    task_info "Bash version: ${BASH_VERSION}"

    if [[ -z "${BASH_VERSION:-}" ]]; then
        task_warning "Not running in bash. Some features may not work. Bash >= 4.0 recommended."
    fi

    show_distro_hints

    if ! command_exists curl; then
        task_warning "curl not found. It is required for downloading."
        install_packages curl
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"
    load_config

    script_title "🌶️  Spicetify Universal Setup v${SCRIPT_VERSION} 🌶️"
    printf '   Works on Arch • Debian • Ubuntu • Fedora • openSUSE • Alpine + more\n'
    printf '   Supports bash • zsh • fish\n\n'

    if [[ "${DRY_RUN}" == "1" ]]; then
        printf '  %s%s⚠ DRY-RUN mode — no changes will be made%s\n\n' "${COLOR_YELLOW}" "${BOLD}" "${COLOR_RESET}"
    fi

    preflight_checks
    check_sudo

    install_packages curl unzip

    if ! command_exists flatpak; then
        task_warning "Flatpak not found."
        if confirm "Install Flatpak now?" "y/N" "N"; then
            install_packages flatpak
            show_distro_hints
            task_error_exit "Please install Spotify from Flatpak and run it once before running this script."
        else
            task_error_exit "Flatpak is required to continue."
        fi
    fi

    get_spotify_flatpak_paths

    if ! grant_permissions; then
        task_warning "Permission issues detected. Continuing anyway..."
    fi

    install_spicetify_cli
    make_path_persistent

    configure_spicetify
    apply_patches
    apply_theme

    printf '\n%s%s🎉 SUCCESS! Spotify is now spiced up!%s\n\n' "${COLOR_GREEN}" "${BOLD}" "${COLOR_RESET}"
    printf '  %s→ Restart Spotify to see your new look.%s\n\n' "${COLOR_SPICETIFY}" "${COLOR_RESET}"

    printf '%s%sNext Steps:%s\n' "${COLOR_BLUE}" "${BOLD}" "${COLOR_RESET}"
    task_detail "• Open Spotify → Marketplace (left sidebar) to browse themes & extensions"
    task_detail "• Change theme: ${COLOR_CYAN}spicetify config current_theme THEME_NAME${COLOR_RESET}"
    task_detail "• Update Spicetify CLI: ${COLOR_CYAN}spicetify upgrade${COLOR_RESET}"
    task_detail "• After Spotify updates: re-run this script or manually: ${COLOR_CYAN}spicetify restore && spicetify backup apply${COLOR_RESET}"

    printf '\n%sTip:%s If you see issues after a Spotify update, just re-run this script.\n\n' "${COLOR_YELLOW}" "${COLOR_RESET}"
}

main "$@"