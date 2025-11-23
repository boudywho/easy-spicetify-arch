#!/bin/bash

readonly SCRIPT_VERSION="2.3.3"
readonly SPOTIFY_FLATPAK_ID="com.spotify.Client"

COLOR_RESET='\033[0m'; COLOR_RED='\033[0;31m'; COLOR_GREEN='\033[0;32m'; COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'; COLOR_PURPLE='\033[0;35m'; COLOR_CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'

if [[ "$(tput colors)" -ge 256 ]]; then
    COLOR_SPICETIFY='\033[38;5;199m'
else
    COLOR_SPICETIFY=$COLOR_PURPLE
fi

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

task_info() {
    printf "  ${COLOR_CYAN}ⓘ %s${COLOR_RESET}\n" "$1"
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

check_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        if ! sudo -n true 2>/dev/null; then
            printf "  ${COLOR_YELLOW}ⓘ Sudo requires a password. Please enter it when prompted.${COLOR_RESET}\n"
            if ! sudo -v; then task_error_exit "Sudo privileges required and could not be obtained."; fi
        fi
        if ! sudo true; then task_error_exit "Sudo check failed. Cannot execute commands with sudo."; fi
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

install_package() {
    local pkg_name="$1"; local pkg_manager_cmd="$2"; local pkg_check_cmd="${3:-$pkg_name}"
    section_header "Installing ${pkg_name}"
    if command_exists "$pkg_check_cmd"; then
        task_success "${pkg_name} is already installed."
        return 0
    fi

    task_running "Attempting to install ${pkg_name} via pacman..."
    if sudo ${pkg_manager_cmd}; then
        task_success "${pkg_name} installed successfully."
    else
        task_error_exit "Failed to install ${pkg_name}."
    fi
}

install_spicetify_cli() {
    section_header "Spicetify CLI Installation"

    if [[ -d "$HOME/.spicetify" ]]; then
        export PATH="$HOME/.spicetify:$PATH"
    fi

    if command_exists "spicetify"; then
        if ! confirm "Spicetify CLI seems installed. Re-run its installer (for updates & Marketplace)?" "y/N" "N"; then
            task_success "Spicetify CLI already installed. Skipping installer."
            return 0
        fi
        task_running "Proceeding with Spicetify CLI re-installation/update..."
    fi

    task_running "Executing Spicetify's official installer script..."
    task_detail "This script will handle downloads, PATH setup, and Marketplace."

    export SPOTIFY_PATH="$SPOTIFY_APP_FILES_PATH"
    export PREFS_PATH="$SPOTIFY_PREFS_PATH"

    echo
    local installer_exit_code=0
    bash <(curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh) || installer_exit_code=$?
    echo

    if [[ $installer_exit_code -eq 0 ]]; then
        task_success "Spicetify CLI installer script finished."
    else
        task_warning "Spicetify CLI installer script finished with exit code ${installer_exit_code}."
        task_detail "This is common if the marketplace install step failed inside the installer."
    fi

    task_running "Updating PATH for the current session..."

    if [[ -d "$HOME/.spicetify" ]]; then
        export PATH="$HOME/.spicetify:$PATH"
        task_success "Added $HOME/.spicetify to PATH."
    else
        task_warning "$HOME/.spicetify directory not found."
    fi

    if ! command_exists "spicetify"; then
        task_error_exit "Spicetify CLI not found in PATH after install. Check manually."
    fi
    task_success "Spicetify CLI is now available in PATH."

    if [[ $installer_exit_code -eq 127 ]]; then
        task_running "Attempting to install Marketplace manually..."
        curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | bash
    fi
}

get_spotify_flatpak_paths() {
    section_header "Locating Spotify Flatpak"
    if ! command_exists "flatpak"; then task_error_exit "Flatpak command not found."; fi

    local flatpak_location_cmd_output=""
    task_running "Attempting to get Spotify Flatpak location using 'sudo flatpak info --show-location'..."
    flatpak_location_cmd_output=$(sudo flatpak info --show-location "${SPOTIFY_FLATPAK_ID}" 2>/dev/null)

    if [[ -n "$flatpak_location_cmd_output" && -d "$flatpak_location_cmd_output" ]]; then
        SPOTIFY_FLATPAK_LOCATION="$flatpak_location_cmd_output"
        task_success "Found Flatpak system location: ${SPOTIFY_FLATPAK_LOCATION}"
    else
        task_warning "'sudo flatpak info --show-location' failed or returned invalid path."
        task_detail "Output: '${flatpak_location_cmd_output}'"
        task_running "Attempting 'flatpak info --show-location' (no sudo, for user install)..."
        flatpak_location_cmd_output=$(flatpak info --show-location "${SPOTIFY_FLATPAK_ID}" 2>/dev/null)
        if [[ -n "$flatpak_location_cmd_output" && -d "$flatpak_location_cmd_output" ]]; then
            SPOTIFY_FLATPAK_LOCATION="$flatpak_location_cmd_output"
            task_success "Found Flatpak user location: ${SPOTIFY_FLATPAK_LOCATION}"
        else
            task_detail "Output: '${flatpak_location_cmd_output}'"
            task_error_exit "All 'flatpak info --show-location' attempts failed."
        fi
    fi

    SPOTIFY_APP_FILES_PATH="${SPOTIFY_FLATPAK_LOCATION}/files/extra/share/spotify"
    local alt_app_files_path="${SPOTIFY_FLATPAK_LOCATION}/files/share/spotify"

    if [[ -d "$SPOTIFY_APP_FILES_PATH" ]]; then
        task_detail "Spotify app files dir target: ${SPOTIFY_APP_FILES_PATH}"
    elif [[ -d "$alt_app_files_path" ]]; then
        task_detail "Primary app files path not found. Using alternative: ${alt_app_files_path}"
        SPOTIFY_APP_FILES_PATH="$alt_app_files_path"
    else
        task_detail "Spotify app files dir NOT found. Will try to use/create: ${SPOTIFY_APP_FILES_PATH}"
    fi

    SPOTIFY_PREFS_PATH="${HOME}/.var/app/${SPOTIFY_FLATPAK_ID}/config/spotify/prefs"
    if [[ ! -f "$SPOTIFY_PREFS_PATH" ]]; then
        task_warning "Spotify prefs file NOT found: ${SPOTIFY_PREFS_PATH}."
        task_detail "Run Spotify once to generate it."
    else
        task_success "Spotify prefs file found: ${SPOTIFY_PREFS_PATH}"
    fi

    export SPOTIFY_APP_FILES_PATH SPOTIFY_PREFS_PATH
}

grant_permissions() {
    section_header "Granting Filesystem Permissions"
    if [[ -z "$SPOTIFY_APP_FILES_PATH" ]]; then
        task_warning "Spotify app files path not set. Skipping permissions."
        return 1
    fi

    if [[ ! -d "${SPOTIFY_APP_FILES_PATH}" ]]; then
        task_running "Target app files directory does not exist. Creating: ${SPOTIFY_APP_FILES_PATH}"
        if ! sudo mkdir -p "${SPOTIFY_APP_FILES_PATH}"; then task_error_exit "Failed to create directory ${SPOTIFY_APP_FILES_PATH}."; fi
        task_success "Created directory: ${SPOTIFY_APP_FILES_PATH}"
    fi

    task_running "Setting permissions on: ${SPOTIFY_APP_FILES_PATH}"
    if ! sudo chmod a+wr "${SPOTIFY_APP_FILES_PATH}"; then task_error_exit "chmod failed for ${SPOTIFY_APP_FILES_PATH}"; fi
    task_success "Permissions set for ${SPOTIFY_APP_FILES_PATH}"

    local spotify_apps_subdir="${SPOTIFY_APP_FILES_PATH}/Apps"
    if [[ -d "${spotify_apps_subdir}" ]]; then
        task_running "Setting permissions on: ${spotify_apps_subdir}"
        if ! sudo chmod a+wr -R "${spotify_apps_subdir}"; then task_error_exit "chmod failed for ${spotify_apps_subdir}"; fi
        task_success "Permissions set for ${spotify_apps_subdir}"
    else
        task_detail "${spotify_apps_subdir} not found. Spicetify should create it if needed."
    fi
    return 0
}

configure_and_backup_spicetify() {
    section_header "Configuring Spicetify & Applying Patches"
    if ! command_exists "spicetify"; then task_error_exit "Spicetify command not found."; fi

    local spicetify_config_file
    spicetify_config_file="$(spicetify -c 2>/dev/null || true)"
    if [[ -z "$spicetify_config_file" ]]; then
        spicetify_config_file="$HOME/.config/spicetify/config-xpui.ini"
    fi
    mkdir -p "$(dirname "$spicetify_config_file")"

    task_running "Ensuring Spicetify base config file exists..."
    if [[ ! -f "$spicetify_config_file" ]]; then
        task_detail "Spicetify config not found. Running 'spicetify backup' to generate it."
        if ! spicetify backup >/dev/null 2>&1; then
            if ! spicetify >/dev/null 2>&1 && [[ ! -f "$spicetify_config_file" ]]; then
                task_warning "Failed to auto-generate Spicetify config via 'spicetify' command."
            fi
        fi
        if [[ -f "$spicetify_config_file" ]]; then
            task_success "Spicetify config file generated/found."
        else
            task_warning "Spicetify config still not found. Creating a minimal one."
            printf '%s\n' \
                "[Setting]" \
                "current_theme=SpicetifyDefault" \
                "color_scheme=" \
                "prefs_path=${SPOTIFY_PREFS_PATH:-}" \
                "spotify_path=${SPOTIFY_APP_FILES_PATH:-}" \
                "inject_css=1" \
                "replace_colors=1" \
                "overwrite_assets=0" \
                "spotify_launch_flags=" \
                "check_spicetify_upgrade=0" \
                "" \
                "[Preprocesses]" \
                "disable_sentry=1" \
                "disable_ui_logging=1" \
                "remove_rtl_rule=1" \
                "expose_apis=1" \
                "disable_upgrade_notice=1" \
                "" \
                "[AdditionalOptions]" \
                "custom_apps=" \
                "sidebar_config=1" \
                "home_config=1" \
                "experimental_features=0" \
                "" \
                "[Patch]" > "$spicetify_config_file"
            task_success "Minimal Spicetify config created."
        fi
    else
        task_detail "Spicetify config file already exists: ${spicetify_config_file}."
    fi

    if [[ -n "$SPOTIFY_PREFS_PATH" && -f "$SPOTIFY_PREFS_PATH" ]]; then
        task_running "Force-setting 'prefs_path' in Spicetify config..."
        if grep -Eq '^[# ]*prefs_path[[:space:]]*=' "$spicetify_config_file"; then
            sed -i.bak "s|^[# ]*prefs_path[[:space:]]*=.*|prefs_path = ${SPOTIFY_PREFS_PATH}|" "$spicetify_config_file"
        else
            if grep -q '^\[Setting\]' "$spicetify_config_file"; then
                sed -i "/^\[Setting\]/a prefs_path = ${SPOTIFY_PREFS_PATH}" "$spicetify_config_file"
            else
                printf '%s\n' "[Setting]" "prefs_path = ${SPOTIFY_PREFS_PATH}" >> "$spicetify_config_file"
            fi
        fi
        task_success "Verified 'prefs_path' in config."
    else
        task_warning "Spotify prefs file not found. Cannot force-set 'prefs_path'."
    fi

    if [[ -n "$SPOTIFY_APP_FILES_PATH" ]]; then
        task_running "Force-setting 'spotify_path' in Spicetify config..."
        if grep -Eq '^[# ]*spotify_path[[:space:]]*=' "$spicetify_config_file"; then
            sed -i.bak "s|^[# ]*spotify_path[[:space:]]*=.*|spotify_path = ${SPOTIFY_APP_FILES_PATH}|" "$spicetify_config_file"
        else
            if grep -q '^\[Setting\]' "$spicetify_config_file"; then
                sed -i "/^\[Setting\]/a spotify_path = ${SPOTIFY_APP_FILES_PATH}" "$spicetify_config_file"
            else
                printf '%s\n' "[Setting]" "spotify_path = ${SPOTIFY_APP_FILES_PATH}" >> "$spicetify_config_file"
            fi
        fi
        task_success "Verified 'spotify_path' in config."
    else
        task_warning "SPOTIFY_APP_FILES_PATH not set. Cannot force-set 'spotify_path'."
    fi

    task_running "Resetting color_scheme to auto (prevents 'scheme not found' warnings)..."
    if grep -Eq '^[# ]*color_scheme[[:space:]]*=' "$spicetify_config_file"; then
        sed -i.bak "s|^[# ]*color_scheme[[:space:]]*=.*|color_scheme = |" "$spicetify_config_file"
    else
        if grep -q '^\[Setting\]' "$spicetify_config_file"; then
            sed -i "/^\[Setting\]/a color_scheme = " "$spicetify_config_file"
        fi
    fi

    if [[ -z "$SPOTIFY_PREFS_PATH" || ! -f "$SPOTIFY_PREFS_PATH" ]]; then
        task_warning "Spotify 'prefs' file ('${SPOTIFY_PREFS_PATH:-not found}') is STILL missing."
        task_detail "'spicetify backup apply' will fail. Please run Spotify (Flatpak) at least once."
        if ! confirm "Attempt Spicetify operations anyway?" "y/N" "N"; then
            task_error_exit "Aborted due to missing prefs file."
        fi
    fi

    task_running "Attempting to restore Spotify to vanilla state (if already patched)..."
    echo
    if spicetify restore; then
        task_success "Spotify restored to vanilla (or was already vanilla)."
    else
        task_warning "Could not restore Spotify (normal if never patched/backup missing)."
    fi
    echo

    task_running "Running 'spicetify backup apply' (with paths pre-configured)..."
    task_detail "This is the main patching step. Please wait..."
    echo
    if spicetify backup apply; then
        task_success "'spicetify backup apply' command completed."
    else
        task_error_exit "'spicetify backup apply' FAILED. Check Spicetify's output above."
    fi
    echo
}

apply_spicetify_theme_and_extensions() {
    section_header "Applying Spicetify Theme & Extensions"
    if ! command_exists "spicetify"; then task_error_exit "Spicetify command not found."; fi

    task_running "Running 'spicetify apply' to activate customizations..."
    echo
    if spicetify apply; then
        task_success "'spicetify apply' successful! Spotify is spiced up."
    else
        task_error_exit "Failed to 'spicetify apply'. Check Spicetify's output above."
    fi
    echo
}

main() {
    script_title "🌶️  Spicetify Setup for Spotify Flatpak on Arch Linux (v${SCRIPT_VERSION}) 🌶️"

    check_sudo

    if ! command_exists "flatpak"; then task_error_exit "Flatpak is not installed."; fi
    if ! command_exists "gawk"; then install_package "gawk (GNU awk)" "pacman -S --noconfirm gawk" "gawk"; fi
    install_package "curl" "pacman -S --noconfirm curl" "curl"


    get_spotify_flatpak_paths

    if ! grant_permissions; then
        task_warning "Permissions granting encountered issues. Spicetify might fail."
        if ! confirm "Continue with setup despite potential permission issues?" "y/N" "N"; then
            task_error_exit "Aborted by user due to permission concerns."
        fi
    fi

    install_spicetify_cli

    configure_and_backup_spicetify
    apply_spicetify_theme_and_extensions

    printf "\n${COLOR_GREEN}${BOLD}🎉 All done! Spotify should now be spiced up!${COLOR_RESET}\n"
    printf "  ${COLOR_SPICETIFY}ⓘ Restart Spotify to see the changes.${COLOR_RESET}\n"
    echo
    printf "${COLOR_BLUE}${BOLD}  Next Steps & Tips:${COLOR_RESET}\n"

    task_detail "Manage themes: ${COLOR_CYAN}spicetify config current_theme THEME_NAME${DIM}"
    task_detail "Explore Marketplace: Open Spotify (Marketplace item in left panel)."
    task_detail "Spicetify help: ${COLOR_CYAN}spicetify --help${DIM}"
    echo
    task_warning "If issues persist:"
    task_detail " 1. Ensure Spotify (Flatpak) has run AT LEAST ONCE to create '${SPOTIFY_PREFS_PATH:-prefs file}'."
    task_detail " 2. Check permissions on '${SPOTIFY_APP_FILES_PATH:-Spotify app files path}'."
    task_detail " 3. Examine '${HOME}/.config/spicetify/config-xpui.ini' for correct paths."
    task_detail " 4. Try running Spicetify commands manually (e.g., 'spicetify restore', 'spicetify backup apply', 'spicetify apply')."
}

main "$@"
