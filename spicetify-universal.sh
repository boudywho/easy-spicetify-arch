#!/usr/bin/env bash
#
# Spicetify Universal Setup Script
# Version 3.0.4 - Works on Arch, Debian, Ubuntu, Fedora, openSUSE, and more
# Supports bash, zsh, fish, etc.
# Automatically detects package manager, sets up Flatpak Spotify + Spicetify
#

readonly SCRIPT_VERSION="3.0.4"
readonly SPOTIFY_FLATPAK_ID="com.spotify.Client"

# Colors
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'

if [[ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]]; then
    COLOR_SPICETIFY='\033[38;5;199m'
else
    COLOR_SPICETIFY=$COLOR_PURPLE
fi

# =============================================================================
# Helper Functions (UI)
# =============================================================================

script_title() {
    printf "\n${COLOR_SPICETIFY}${BOLD}%b${COLOR_RESET}\n" "$1"
    printf "${COLOR_BLUE}${DIM}%b${COLOR_RESET}\n" "───────────────────────────────────────────────────"
}

section_header() {
    printf "\n${COLOR_BLUE}${BOLD}==> %b${COLOR_RESET}\n" "$1"
}

task_running() {
    printf "  ${COLOR_CYAN}↪ %b${COLOR_RESET}\n" "$1"
}

task_detail() {
    printf "    ${DIM}› %b${COLOR_RESET}\n" "$1"
}

task_info() {
    printf "  ${COLOR_CYAN}ⓘ %b${COLOR_RESET}\n" "$1"
}

task_success() {
    printf "  ${COLOR_GREEN}✓ %b${COLOR_RESET}\n" "$1"
}

task_warning() {
    printf "  ${COLOR_YELLOW}⚠ %b${COLOR_RESET}\n" "$1"
}

task_error_exit() {
    printf "  ${COLOR_RED}${BOLD}✗ ERROR: %b${COLOR_RESET}\n" "$1" >&2
    exit 1
}

command_exists() {
    command -v "$1" &>/dev/null
}

# =============================================================================
# Process Management (Auto-Kill Spotify)
# =============================================================================

kill_spotify() {
    # Check if Spotify is running via flatpak process list
    if flatpak ps --columns=application 2>/dev/null | grep -q "^${SPOTIFY_FLATPAK_ID}$"; then
        task_running "Spotify is running. Closing it automatically..."
        flatpak kill "${SPOTIFY_FLATPAK_ID}" 2>/dev/null || true
        sleep 2
        
        # If it's still persisting
        if flatpak ps --columns=application 2>/dev/null | grep -q "^${SPOTIFY_FLATPAK_ID}$"; then
            task_warning "Spotify is resisting. Forcing it to close..."
            killall -9 spotify 2>/dev/null || true
            sleep 1
        fi

        # Final check
        if flatpak ps --columns=application 2>/dev/null | grep -q "^${SPOTIFY_FLATPAK_ID}$"; then
            task_warning "Could not completely close Spotify automatically."
            if ! confirm "Please close Spotify manually. Is it closed now?" "Y/n" "Y"; then
                task_error_exit "Aborted. Please close Spotify and re-run."
            fi
        else
            task_success "Spotify closed successfully."
        fi
    fi
}

# =============================================================================
# Sudo Handling
# =============================================================================

check_sudo() {
    if [[ "$EUID" -eq 0 && -n "$SUDO_USER" ]]; then
        task_error_exit "Please run this script as your normal user, NOT with sudo. The script will request sudo automatically when needed."
    fi

    if [[ "$EUID" -ne 0 ]]; then
        if ! sudo -n true 2>/dev/null; then
            printf "  ${COLOR_YELLOW}ⓘ Sudo requires a password. Please enter it when prompted.${COLOR_RESET}\n"
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
# Confirmation Prompt
# =============================================================================

confirm() {
    local prompt="${1:-Are you sure?}"
    local char_prompt="${2:-y/N}"
    local default_ans="${3:-N}"

    local response
    while true; do
        read -r -p "$(printf "  ${COLOR_YELLOW}? %b [%b]: ${COLOR_RESET}" "$prompt" "$char_prompt")" response < /dev/tty
        response="${response:-$default_ans}"
        case "$response" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) printf "  ${COLOR_RED}Please answer 'y' or 'n'.${COLOR_RESET}\n" > /dev/tty ;;
        esac
    done
}

# =============================================================================
# Universal Package Manager Detection & Installation
# =============================================================================

detect_package_manager() {
    if command_exists pacman; then
        echo "pacman"
    elif command_exists apt-get || command_exists apt; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists zypper; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

install_package() {
    local pkg_name="$1"
    local pkg_manager
    pkg_manager=$(detect_package_manager)

    section_header "Installing ${pkg_name}"

    if command_exists "$pkg_name"; then
        task_success "${pkg_name} is already installed."
        return 0
    fi

    task_running "Detected package manager: ${pkg_manager}"

    local install_cmd=""
    case "$pkg_manager" in
        pacman)
            install_cmd="sudo pacman -S --noconfirm ${pkg_name}"
            ;;
        apt)
            install_cmd="sudo apt-get update -qq && sudo apt-get install -y ${pkg_name}"
            ;;
        dnf)
            install_cmd="sudo dnf install -y ${pkg_name}"
            ;;
        yum)
            install_cmd="sudo yum install -y ${pkg_name}"
            ;;
        zypper)
            install_cmd="sudo zypper install -y ${pkg_name}"
            ;;
        *)
            task_warning "Unknown package manager. Please install '${pkg_name}' manually."
            return 1
            ;;
    esac

    task_running "Running: ${install_cmd}"
    if eval "$install_cmd"; then
        task_success "${pkg_name} installed successfully."
    else
        task_error_exit "Failed to install ${pkg_name}. Please install it manually and re-run the script."
    fi
}

# =============================================================================
# Flatpak Path Detection
# =============================================================================

get_spotify_flatpak_paths() {
    section_header "Locating Spotify Flatpak"

    if ! command_exists "flatpak"; then
        task_error_exit "Flatpak is not installed. Please install Flatpak and Spotify first."
    fi

    local flatpak_location_cmd_output=""

    task_running "Detecting Spotify Flatpak location (system-wide first)..."
    flatpak_location_cmd_output=$(sudo flatpak info --show-location "${SPOTIFY_FLATPAK_ID}" 2>/dev/null || true)

    if [[ -n "$flatpak_location_cmd_output" && -d "$flatpak_location_cmd_output" ]]; then
        SPOTIFY_FLATPAK_LOCATION="$flatpak_location_cmd_output"
        task_success "Found system-wide Flatpak: ${SPOTIFY_FLATPAK_LOCATION}"
    else
        task_running "Trying user installation..."
        flatpak_location_cmd_output=$(flatpak info --show-location "${SPOTIFY_FLATPAK_ID}" 2>/dev/null || true)

        if [[ -n "$flatpak_location_cmd_output" && -d "$flatpak_location_cmd_output" ]]; then
            SPOTIFY_FLATPAK_LOCATION="$flatpak_location_cmd_output"
            task_success "Found user Flatpak: ${SPOTIFY_FLATPAK_LOCATION}"
        else
            task_error_exit "Could not locate Spotify Flatpak. Is it installed? (flatpak install flathub com.spotify.Client)"
        fi
    fi

    # Primary and fallback paths
    SPOTIFY_APP_FILES_PATH="${SPOTIFY_FLATPAK_LOCATION}/files/extra/share/spotify"
    local alt_app_files_path="${SPOTIFY_FLATPAK_LOCATION}/files/share/spotify"

    if [[ -d "$SPOTIFY_APP_FILES_PATH" ]]; then
        task_detail "Using: ${SPOTIFY_APP_FILES_PATH}"
    elif [[ -d "$alt_app_files_path" ]]; then
        SPOTIFY_APP_FILES_PATH="$alt_app_files_path"
        task_detail "Using alternative: ${SPOTIFY_APP_FILES_PATH}"
    else
        task_detail "Target directory will be created if needed: ${SPOTIFY_APP_FILES_PATH}"
    fi

    SPOTIFY_PREFS_PATH="${HOME}/.var/app/${SPOTIFY_FLATPAK_ID}/config/spotify/prefs"

    if [[ -f "$SPOTIFY_PREFS_PATH" ]]; then
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

    if [[ -z "$SPOTIFY_APP_FILES_PATH" ]]; then
        task_warning "Spotify path not set. Skipping."
        return 1
    fi

    if [[ ! -d "$SPOTIFY_APP_FILES_PATH" ]]; then
        task_running "Creating directory: ${SPOTIFY_APP_FILES_PATH}"
        sudo mkdir -p "$SPOTIFY_APP_FILES_PATH" || task_error_exit "Failed to create directory."
        task_success "Directory created."
    fi

    task_running "Setting permissions on ${SPOTIFY_APP_FILES_PATH}..."
    sudo chmod a+wr "$SPOTIFY_APP_FILES_PATH" || task_error_exit "chmod failed."

    local apps_dir="${SPOTIFY_APP_FILES_PATH}/Apps"
    if [[ -d "$apps_dir" ]]; then
        sudo chmod -R a+wr "$apps_dir"
        task_success "Permissions set (including Apps folder)."
    else
        task_detail "Apps folder will be created by Spicetify if needed."
    fi

    return 0
}

# =============================================================================
# Install Spicetify CLI
# =============================================================================

install_spicetify_cli() {
    section_header "Installing Spicetify CLI"

    # Add to PATH if already installed
    if [[ -d "$HOME/.spicetify" ]]; then
        export PATH="$HOME/.spicetify:$PATH"
    fi

    if command_exists "spicetify"; then
        if ! confirm "Spicetify is already installed. Re-install / update it?" "y/N" "N"; then
            task_success "Skipping Spicetify installation."
            return 0
        fi
        task_running "Proceeding with update..."
    fi

    task_running "Downloading official Spicetify installer..."

    # OFFICIAL CURRENT URL
    local installer_url="https://raw.githubusercontent.com/spicetify/cli/main/install.sh"
    local tmp_installer
    tmp_installer=$(mktemp)

    if ! curl -fsSL "$installer_url" -o "$tmp_installer"; then
        rm -f "$tmp_installer"
        task_error_exit "Failed to download Spicetify installer. Check your internet connection."
    fi

    task_running "Running installer script..."
    
    # We execute it but don't force an exit if it throws an error code. 
    # The Marketplace installer runs `spicetify apply`, which will naturally fail (returns non-zero)
    # since we haven't configured the Spotify Flatpak paths yet. We will configure and apply safely next.
    if ! sh "$tmp_installer"; then
        task_warning "Installer exited with an error (expected if you chose Marketplace). Continuing..."
    else
        task_success "Spicetify CLI installed successfully."
    fi

    rm -f "$tmp_installer"

    # Ensure it's in PATH for this session
    if [[ -d "$HOME/.spicetify" ]]; then
        export PATH="$HOME/.spicetify:$PATH"
    fi

    if ! command_exists "spicetify"; then
        task_error_exit "Spicetify command not found after installation. The installation genuinely failed."
    fi

    task_success "Spicetify is ready."
}

# =============================================================================
# Make PATH Persistent
# =============================================================================

make_path_persistent() {
    section_header "Making Spicetify Available in New Terminals"

    local shell_name
    shell_name=$(basename "$SHELL")

    local rc_file=""
    local export_line='export PATH="$HOME/.spicetify:$PATH"'

    case "$shell_name" in
        bash)
            rc_file="$HOME/.bashrc"
            ;;
        zsh)
            rc_file="$HOME/.zshrc"
            ;;
        fish)
            rc_file="$HOME/.config/fish/config.fish"
            export_line='fish_add_path "$HOME/.spicetify"'
            ;;
        *)
            task_warning "Unknown shell: $shell_name"
            task_detail "Please manually add this line to your shell config:"
            task_detail "$export_line"
            return 0
            ;;
    esac

    if [[ -f "$rc_file" ]] && grep -q ".spicetify" "$rc_file"; then
        task_success "PATH already configured in $rc_file"
        return 0
    fi

    if confirm "Add Spicetify to your PATH permanently in $rc_file?" "Y/n" "Y"; then
        mkdir -p "$(dirname "$rc_file")"
        echo "" >> "$rc_file"
        echo "# Spicetify" >> "$rc_file"
        echo "$export_line" >> "$rc_file"
        task_success "Added to $rc_file. Restart your terminal or run: source $rc_file"
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

    if ! command_exists "spicetify"; then
        task_error_exit "Spicetify not found."
    fi

    # Generate default config if it doesn't exist
    task_running "Ensuring Spicetify config exists..."
    if [[ ! -f "$HOME/.config/spicetify/config-xpui.ini" ]]; then
        spicetify >/dev/null 2>&1 || true
        task_success "Config file generated."
    fi

    # Set the critical paths using the OFFICIAL way
    if [[ -n "$SPOTIFY_APP_FILES_PATH" ]]; then
        task_running "Setting spotify_path..."
        spicetify config spotify_path "$SPOTIFY_APP_FILES_PATH"
        task_success "spotify_path set."
    fi

    if [[ -n "$SPOTIFY_PREFS_PATH" && -f "$SPOTIFY_PREFS_PATH" ]]; then
        task_running "Setting prefs_path..."
        spicetify config prefs_path "$SPOTIFY_PREFS_PATH"
        task_success "prefs_path set."
    else
        task_warning "prefs_path not set (Spotify may not have been run yet)."
    fi

    # Reset color scheme to avoid warnings
    spicetify config color_scheme "" >/dev/null 2>&1 || true

    # Optional: disable some annoyances
    spicetify config check_spicetify_upgrade 0 >/dev/null 2>&1 || true

    task_success "Configuration complete."
}

# =============================================================================
# Apply Patches & Theme
# =============================================================================

apply_patches() {
    section_header "Applying Spicetify Patches"

    kill_spotify

    task_running "Restoring Spotify to vanilla state (safe if already patched)..."
    spicetify restore 2>/dev/null || task_warning "No previous backup found (normal on first run)."

    kill_spotify # Double check in case it reopened in the background

    task_running "Running 'spicetify backup apply' (this patches Spotify)..."
    if spicetify backup apply; then
        task_success "Backup & apply completed."
    else
        task_error_exit "'spicetify backup apply' failed. Check output above."
    fi
}

apply_theme() {
    section_header "Finalizing Setup"

    kill_spotify

    task_running "Running 'spicetify apply'..."
    if spicetify apply; then
        task_success "Spicetify applied successfully!"
    else
        task_error_exit "spicetify apply failed."
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    script_title "🌶️  Spicetify Universal Setup v${SCRIPT_VERSION} 🌶️"
    printf "   Works on Arch • Debian • Ubuntu • Fedora • openSUSE + more\n"
    printf "   Supports bash • zsh • fish\n\n"

    check_sudo

    # Install essentials if missing (curl for downloading, unzip for marketplace)
    for pkg in curl unzip; do
        if ! command_exists "$pkg"; then
            install_package "$pkg"
        fi
    done

    # Optional: install flatpak if missing (user can skip)
    if ! command_exists flatpak; then
        task_warning "Flatpak not found."
        if confirm "Install Flatpak now?" "y/N" "N"; then
            install_package "flatpak"
            task_info "Please run 'flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo' then install Spotify."
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

    printf "\n${COLOR_GREEN}${BOLD}🎉 SUCCESS! Spotify is now spiced up!${COLOR_RESET}\n\n"
    printf "  ${COLOR_SPICETIFY}→ Restart Spotify to see your new look.${COLOR_RESET}\n\n"

    printf "${COLOR_BLUE}${BOLD}Next Steps:${COLOR_RESET}\n"
    task_detail "• Open Spotify → Marketplace (left sidebar) to browse themes & extensions"
    task_detail "• Change theme: ${COLOR_CYAN}spicetify config current_theme THEME_NAME${COLOR_RESET}"
    task_detail "• Update Spicetify CLI: ${COLOR_CYAN}spicetify upgrade${COLOR_RESET}"
    task_detail "• After Spotify updates: re-run this script or manually: ${COLOR_CYAN}spicetify restore && spicetify backup apply${COLOR_RESET}"

    printf "\n${COLOR_YELLOW}Tip:${COLOR_RESET} If you see issues after a Spotify update, just re-run this script.\n\n"
}

main "$@"
