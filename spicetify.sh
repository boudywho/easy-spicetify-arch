#!/bin/bash

readonly SCRIPT_VERSION="3.0.0"
readonly SPOTIFY_FLATPAK_ID="com.spotify.Client"

# ANSI Colors
COLOR_RESET='\033[0m'; COLOR_RED='\033[0;31m'; COLOR_GREEN='\033[0;32m'; COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'; COLOR_PURPLE='\033[0;35m'; COLOR_CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'

# Check for 256 color support
if [[ "$(tput colors)" -ge 256 ]]; then
    COLOR_SPICETIFY='\033[38;5;199m'
else
    COLOR_SPICETIFY=$COLOR_PURPLE
fi

# ==========================================
# UI / LOGGING FUNCTIONS
# ==========================================

script_title() {
    printf "\n${COLOR_SPICETIFY}${BOLD}%s${COLOR_RESET}\n" "$1"
    printf "${COLOR_BLUE}${DIM}%s${COLOR_RESET}\n" "───────────────────────────────────────────────────"
}

section_header() {
    printf "\n${COLOR_BLUE}${BOLD}==> %s${COLOR_RESET}\n" "$1"
}

task_running() {
    printf "  ${COLOR_CYAN}↪ %s${COLOR_RESET}\n" "$1"
}

task_detail() {
    printf "    ${DIM}› %s${COLOR_RESET}\n" "$1"
}

task_success() {
    printf "  ${COLOR_GREEN}✓ %s${COLOR_RESET}\n" "$1"
}

task_warning() {
    printf "  ${COLOR_YELLOW}⚠ %s${COLOR_RESET}\n" "$1"
}

task_error_exit() {
    printf "  ${COLOR_RED}${BOLD}✗ ERROR: %s${COLOR_RESET}\n" "$1" >&2
    exit 1
}

command_exists() { command -v "$1" &>/dev/null; }

# ==========================================
# SYSTEM & PERMISSION CHECKS
# ==========================================

check_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        if ! sudo -n true 2>/dev/null; then
            printf "  ${COLOR_YELLOW}ⓘ Sudo requires a password. Please enter it when prompted.${COLOR_RESET}\n"
            if ! sudo -v; then task_error_exit "Sudo privileges required and could not be obtained."; fi
        fi
        task_success "Sudo privileges verified."
    else
        task_success "Running as root."
    fi
}

confirm() {
    local prompt="${1:-Are you sure?}"
    local char_prompt="${2:-y/N}"
    local default_ans="${3:-N}"

    local response
    while true; do
        read -r -p "$(printf "  ${COLOR_YELLOW}? %s [%s]: ${COLOR_RESET}" "$prompt" "$char_prompt")" response < /dev/tty
        response="${response:-$default_ans}"
        case "$response" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) printf "  ${COLOR_RED}Please answer 'y' or 'n'.${COLOR_RESET}\n" > /dev/tty ;;
        esac
    done
}

# ==========================================
# PACKAGE MANAGEMENT (MULTI-DISTRO)
# ==========================================

detect_package_manager() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID=$ID
        OS_LIKE=$ID_LIKE
    else
        task_warning "Could not detect OS via /etc/os-release."
        OS_ID="unknown"
    fi

    if command_exists "pacman"; then
        PKG_MANAGER="pacman"
        PKG_INSTALL_CMD="sudo pacman -S --noconfirm"
        PKG_UPDATE_CMD="sudo pacman -Sy"
    elif command_exists "apt-get"; then
        PKG_MANAGER="apt"
        PKG_INSTALL_CMD="sudo apt-get install -y"
        PKG_UPDATE_CMD="sudo apt-get update"
    elif command_exists "dnf"; then
        PKG_MANAGER="dnf"
        PKG_INSTALL_CMD="sudo dnf install -y"
        PKG_UPDATE_CMD="sudo dnf check-update"
    else
        task_error_exit "Unsupported package manager. Please install dependencies manually."
    fi
}

install_dependency() {
    local pkg_name="$1"
    local check_cmd="${2:-$pkg_name}"
    
    # Map generic package names to distro-specific names if necessary
    if [[ "$PKG_MANAGER" == "apt" && "$pkg_name" == "gawk" ]]; then
        pkg_name="gawk" # Usually essentially the same, but ensuring explicit naming
    fi

    if command_exists "$check_cmd"; then
        task_success "Dependency '${pkg_name}' is already installed."
        return 0
    fi

    section_header "Installing Dependency: ${pkg_name}"
    task_running "Detected package manager: ${PKG_MANAGER}"
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
         task_detail "Updating apt cache first..."
         $PKG_UPDATE_CMD >/dev/null 2>&1
    fi

    task_running "Installing ${pkg_name}..."
    if $PKG_INSTALL_CMD "$pkg_name"; then
        task_success "${pkg_name} installed successfully."
    else
        task_error_exit "Failed to install ${pkg_name} using ${PKG_MANAGER}."
    fi
}

# ==========================================
# SPICETIFY INSTALLATION
# ==========================================

install_spicetify_cli() {
    section_header "Spicetify CLI Installation"

    if [[ -d "$HOME/.spicetify" ]]; then
        export PATH="$HOME/.spicetify:$PATH"
    fi

    if command_exists "spicetify"; then
        if ! confirm "Spicetify CLI seems installed. Re-run installer (updates & Marketplace)?" "y/N" "N"; then
            task_success "Skipping Spicetify CLI installation."
            return 0
        fi
        task_running "Proceeding with re-installation/update..."
    fi

    task_running "Downloading and executing Spicetify installer..."
    task_detail "This handles downloads, PATH setup, and Marketplace."

    # Set paths for the installer to pick up
    export SPOTIFY_PATH="$SPOTIFY_APP_FILES_PATH"
    export PREFS_PATH="$SPOTIFY_PREFS_PATH"

    echo
    local installer_exit_code=0
    curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh | sh || installer_exit_code=$?
    echo

    if [[ $installer_exit_code -eq 0 ]]; then
        task_success "Spicetify CLI installer script finished."
    else
        task_warning "Installer finished with exit code ${installer_exit_code}."
    fi

    # Ensure PATH is updated for current session logic
    if [[ -d "$HOME/.spicetify" ]]; then
        export PATH="$HOME/.spicetify:$PATH"
    fi

    if ! command_exists "spicetify"; then
        task_error_exit "Spicetify CLI not found in PATH after install."
    fi
    task_success "Spicetify CLI available."

    # Marketplace manual fallback
    if [[ $installer_exit_code -ne 0 ]]; then
        task_running "Attempting manual Marketplace install (curl pipe)..."
        curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh
    fi
}

# ==========================================
# FLATPAK DISCOVERY & PERMISSIONS
# ==========================================

get_spotify_flatpak_paths() {
    section_header "Locating Spotify Flatpak"
    
    local flatpak_location_cmd_output=""
    task_running "Querying Flatpak for Spotify location..."
    
    # Try system install first
    flatpak_location_cmd_output=$(flatpak info --show-location "${SPOTIFY_FLATPAK_ID}" 2>/dev/null)
    
    if [[ -z "$flatpak_location_cmd_output" ]]; then
        # Try sudo if user level failed (rare but possible with weird permissions)
        flatpak_location_cmd_output=$(sudo flatpak info --show-location "${SPOTIFY_FLATPAK_ID}" 2>/dev/null)
    fi

    if [[ -n "$flatpak_location_cmd_output" && -d "$flatpak_location_cmd_output" ]]; then
        SPOTIFY_FLATPAK_LOCATION="$flatpak_location_cmd_output"
        task_success "Found Flatpak location: ${SPOTIFY_FLATPAK_LOCATION}"
    else
        task_error_exit "Could not find Spotify Flatpak location. Is it installed? (com.spotify.Client)"
    fi

    # Standard Flatpak paths
    SPOTIFY_APP_FILES_PATH="${SPOTIFY_FLATPAK_LOCATION}/files/extra/share/spotify"
    local alt_app_files_path="${SPOTIFY_FLATPAK_LOCATION}/files/share/spotify"

    if [[ -d "$SPOTIFY_APP_FILES_PATH" ]]; then
        task_detail "Target: ${SPOTIFY_APP_FILES_PATH}"
    elif [[ -d "$alt_app_files_path" ]]; then
        task_detail "Using alternate path: ${alt_app_files_path}"
        SPOTIFY_APP_FILES_PATH="$alt_app_files_path"
    else
        task_warning "Spotify files directory not found. Will attempt to create/use: ${SPOTIFY_APP_FILES_PATH}"
    fi

    SPOTIFY_PREFS_PATH="${HOME}/.var/app/${SPOTIFY_FLATPAK_ID}/config/spotify/prefs"
    if [[ ! -f "$SPOTIFY_PREFS_PATH" ]]; then
        task_warning "Spotify prefs file NOT found: ${SPOTIFY_PREFS_PATH}."
        task_detail "Run Spotify once to generate it."
    else
        task_success "Prefs found: ${SPOTIFY_PREFS_PATH}"
    fi

    export SPOTIFY_APP_FILES_PATH SPOTIFY_PREFS_PATH
}

grant_permissions() {
    section_header "Granting Filesystem Permissions"
    
    if [[ ! -d "${SPOTIFY_APP_FILES_PATH}" ]]; then
        task_running "Creating app directory: ${SPOTIFY_APP_FILES_PATH}"
        sudo mkdir -p "${SPOTIFY_APP_FILES_PATH}"
    fi

    task_running "Setting write permissions on Spotify directory..."
    # Using chmod a+wr to allow Spicetify (running as user) to modify Flatpak files (owned by root)
    if ! sudo chmod -R a+wr "${SPOTIFY_APP_FILES_PATH}"; then 
        task_error_exit "chmod failed for ${SPOTIFY_APP_FILES_PATH}"; 
    fi
    task_success "Permissions set successfully."
}

# ==========================================
# CONFIGURATION & APPLY
# ==========================================

configure_and_backup_spicetify() {
    section_header "Configuring Spicetify"
    
    local spicetify_config_file
    spicetify_config_file="$(spicetify -c 2>/dev/null || echo "$HOME/.config/spicetify/config-xpui.ini")"
    mkdir -p "$(dirname "$spicetify_config_file")"

    # Generate config if missing
    if [[ ! -f "$spicetify_config_file" ]]; then
        task_running "Generating initial config..."
        spicetify config current_theme "SpicetifyDefault" >/dev/null 2>&1
        spicetify config color_scheme " " >/dev/null 2>&1
    fi

    # Set Paths
    task_running "Setting Spicetify paths..."
    spicetify config prefs_path "$SPOTIFY_PREFS_PATH" >/dev/null 2>&1
    spicetify config spotify_path "$SPOTIFY_APP_FILES_PATH" >/dev/null 2>&1
    
    # Flatpak Specific Settings
    spicetify config inject_css 1 replace_colors 1 overwrite_assets 1 >/dev/null 2>&1
    
    # Preprocesses
    spicetify config disable_sentry 1 disable_ui_logging 1 disable_upgrade_notice 1 >/dev/null 2>&1

    task_success "Configuration updated."

    # Backup & Apply
    if [[ -f "$SPOTIFY_PREFS_PATH" ]]; then
        section_header "Backup and Apply"
        task_running "Backing up and applying (this may take a moment)..."
        echo
        spicetify backup apply
        if [[ $? -eq 0 ]]; then
            task_success "Spicetify applied successfully."
        else
            task_error_exit "Backup/Apply failed. Check output above."
        fi
    else
        task_warning "Skipping 'backup apply' because prefs file is missing."
    fi
}

main() {
    script_title "🌶️  Spicetify for Flatpak (Universal Linux) v${SCRIPT_VERSION} 🌶️"

    check_sudo
    detect_package_manager

    # 1. Check Dependencies
    if ! command_exists "flatpak"; then 
        task_error_exit "Flatpak is not installed. Please install Flatpak and Spotify first."; 
    fi
    
    install_dependency "curl"
    install_dependency "gawk" # GNU Awk is required by Spicetify

    # 2. Locate Spotify
    get_spotify_flatpak_paths

    # 3. Permissions
    if ! grant_permissions; then
        task_error_exit "Failed to set permissions."
    fi

    # 4. Install CLI
    install_spicetify_cli

    # 5. Configure & Patch
    configure_and_backup_spicetify

    echo
    printf "${COLOR_GREEN}${BOLD}🎉 Installation Complete!${COLOR_RESET}\n"
    printf "  ${COLOR_SPICETIFY}Restart Spotify to see changes.${COLOR_RESET}\n"
}

main "$@"
