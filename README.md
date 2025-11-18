# Spice Up Your Spotify on Arch Linux  
### The (Mostly) Hands-Off Spicetify Installer – Flatpak Edition

[![Script Version](https://img.shields.io/badge/Script%20Version-v2.3.0-success?style=for-the-badge&logo=bash)](./spicetify.sh)  
[![GitHub Stars](https://img.shields.io/github/stars/boudywho/easy-spicetify-arch?style=for-the-badge&logo=github&label=Star%20Me!)](https://github.com/boudywho/easy-spicetify-arch/stargazers)  
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](./LICENSE)

**This script exists because I got tired of fighting Spicetify + Flatpak on Arch.**  
It went through a *lot* of trial and error: broken paths, missing prefs, Flatpak quirks, shell weirdness, you name it. The goal now is simple:

> You run **one script**, it does the annoying parts, and you end up with a customized Spotify + Marketplace.

If this saves you a couple of hours or some sanity, a ⭐ on GitHub is genuinely appreciated and helps me keep polishing it.

---

## ✨ What the `spicetify.sh` Script Does for You

- **End-to-end automation**: Installs dependencies, runs the official Spicetify installer, fixes its config, and applies the patches.
- **Smart Spotify Flatpak detection**: Finds the correct Spotify Flatpak path (system or user), and wires it into Spicetify.
- **Safe to re-run**: Idempotent by design. If you run it multiple times, it won’t trash your setup. It just updates/fixes things.
- **Nice, readable output**: Color-coded sections, clear steps, and helpful messages instead of a wall of text.
- **Marketplace ready**: Hooks into the official installer and prompts you to install the Spicetify Marketplace.
- **Good error reporting**: If something goes wrong (missing prefs, permissions, etc.), the script tries to tell you *what* and *where*.
- **Reasonably sane Bash**: Structured functions, no wild spaghetti, and tuned for Arch + Flatpak.

---

## 🚀 Recommended: One-Command Install with `spicetify.sh`

### ✅ Requirements
- Arch or an Arch-based distro
- Spotify (Flatpak) from Flathub:
  ```bash
  flatpak install flathub com.spotify.Client

* Basic terminal comfort (copy/paste and running scripts)

### 🧩 Installation Steps

1. **Clone the repo**

   ```bash
   git clone https://github.com/boudywho/easy-spicetify-arch.git
   cd easy-spicetify-arch
   ```
2. **Make the script executable**

   ```bash
   chmod +x spicetify.sh
   ```
3. **Run it**

   ```bash
   ./spicetify.sh
   ```

   During the run:

   * It may ask for your `sudo` password to install missing tools and fix permissions.
   * When the Spicetify CLI prompt appears:

     > Do you want to install spicetify Marketplace? (Y/n)
     > Type `y` unless you really don’t want it.
4. **Restart Spotify**
   Close Spotify and open it again. You should see your theme + Marketplace. (usually as a new entry in the left sidebar).

---

## 🛠️ Troubleshooting (With the Script)

Most issues fall into one of these buckets:

### 🧩 “Cannot detect Spotify prefs file” / `prefs_path` complaints

* Make sure you have **run Spotify at least once**:

  ```bash
  flatpak run com.spotify.Client
  ```

  Then close it and re-run:

  ```bash
  ./spicetify.sh
  ```

* The script now:

  * Detects Spotify’s Flatpak path
  * Detects your prefs file
  * Forces `prefs_path` and `spotify_path` into the Spicetify config it actually uses.

If you still see prefs errors after a full run, open an issue and paste the full output.

---

### 🔐 Permission issues

If Spicetify complains about writing/patching:

* The script already does:

  ```bash
  sudo chmod a+wr -R /var/lib/flatpak/app/com.spotify.Client/.../files/extra/share/spotify
  ```

  and the `Apps` directory under it.

If you’re still stuck, include the exact error message in a GitHub issue.

---

### 🧾 Need help?

If anything looks off or half-works:

* Open an issue here:
  👉 [https://github.com/boudywho/spicetify-arch-installation-guide/issues](https://github.com/boudywho/spicetify-arch-installation-guide/issues)
* Please include:

  * Script version (e.g. `v2.2.2`)
  * Your distro / DE
  * The **full** script output (pasted as a code block or attached)

---

## 🧠 Manual Installation (For Curious / Advanced Users)

You *don’t* need this if you use the script.
This is just the “what the script automates for you” section.

### 1. Install prerequisites

```bash
sudo pacman -S curl gawk --noconfirm
```

### 2. Install Spicetify CLI + Marketplace

```bash
curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh | bash
```

Follow the prompts, and make sure `spicetify` ends up in your `PATH`.

### 3. Find Spotify’s Flatpak paths

**Spotify install path:**

```bash
sudo flatpak info --show-location com.spotify.Client
# or, if installed per-user:
# flatpak info --show-location com.spotify.Client
```

The **spotify_path** is usually:

```text
<that_location>/files/extra/share/spotify
# or sometimes:
<that_location>/files/share/spotify
```

**Spotify prefs path:**

Usually:

```bash
~/.var/app/com.spotify.Client/config/spotify/prefs
```

(Again, this file only exists after you’ve run Spotify at least once.)

### 4. Configure Spicetify

Let Spicetify know where Spotify and your prefs live:

```bash
spicetify config spotify_path /your/spotify/path
spicetify config prefs_path /your/prefs/path
```

You can confirm which config file Spicetify uses with:

```bash
spicetify -c
```

### 5. Fix permissions

Replace `<Spotify App Files Path>` with your actual path from step 3:

```bash
sudo chmod a+wr -R "<Spotify App Files Path>"
sudo chmod a+wr -R "<Spotify App Files Path>/Apps"
```

### 6. Apply Spicetify

```bash
spicetify restore
spicetify backup apply
spicetify apply
```

---

## 🎨 Customizing Spotify Afterward

Once everything is patched:

* Open Spotify and look for the **Marketplace** entry in the sidebar

  * Browse themes, extensions, and custom apps
* Use the CLI for quick tweaks, e.g.:

  ```bash
  spicetify config current_theme marketplace
  spicetify config color_scheme dark
  spicetify apply
  ```
* For more options:

  ```bash
  spicetify --help
  ```

---

## 📜 Changelog – `spicetify.sh`


### v2.3.0 — Major Reliability Update

A focused stability release that fixes shell-related exits, config mismatches, and Marketplace setup issues. Most users should now get a smooth **one-run installation**, even on Zsh.
- **Correct shell detection:** Uses `$SHELL` to avoid sourcing the wrong rc file, fixing the Zsh `exit 127` issue.  
- **Safe rc sourcing:** Applies `set +e` after loading shell configs to prevent user-defined options from breaking the installer.  
- **Reliable config handling:** Automatically detects and edits the correct Spicetify config file using `spicetify -c`.  
- **Marketplace installs on first run:** Improved initialization ensures stable patching and consistent Marketplace setup.

### v2.2.2 – Fixes

* Fixed errors, script is back to working again.
* Minor polish to keep output consistent and readable.

### v2.2.1 – Output polish

* Fixed some `task_detail` lines to render ANSI codes exactly as intended.
* Simplified `grep` checks in `configure_and_backup_spicetify` to use `grep -Fq` for path verification.

### v2.2.0 – New output system

* Replaced ad-hoc `echo` spam with structured output helpers:

  * `script_title`, `section_header`, `task_running`, `task_detail`, `task_info`,
    `task_success`, `task_warning`, `task_error_exit`
* Introduced a more consistent color scheme and layout for better readability.
* Improved interactive prompt UX in `confirm`.

### v2.1.9 – Config check robustness

* Tightened `grep` patterns around config verification to better handle weird spacing.

### v2.1.8 – Idempotent and first-run friendly

* Always tries `spicetify restore` before `spicetify backup apply` to ensure a clean base.
* Switched `sed` to use `|` as a delimiter to avoid conflicts with paths.
* Verified config edits with exact string checks.

### v2.1.7 – Sudo check fix

* Fixed a bug in `check_sudo` that could prevent the script from running.
* Slightly improved path escaping for `sed` replacements.

### v2.1.6 – The big config breakthrough

* Guaranteed a base `config-xpui.ini` exists (creates a minimal one if needed).
* Explicitly forces `prefs_path` and `spotify_path` into the config before running `spicetify backup apply`.
* This change dramatically improved reliability with Flatpak builds.

### v2.1.5 – Reliable Flatpak path detection

* Switched `get_spotify_flatpak_paths` to use:

  ```bash
  flatpak info --show-location com.spotify.Client
  ```
* Kept fallback logic for edge cases but this covers most setups cleanly.

### v2.1.4 – Extra Flatpak debugging

* Improved diagnostics around `flatpak info` when paths couldn’t be detected.
* Helped track down several earlier bugs.

### v2.1.3 – Path parsing improvements

* Swapped naive parsing with `gawk` and proper fallbacks.
* Added more debug lines to understand failures on different systems.

### v2.1.2 – Interactive installer support

* Allowed the Spicetify installer script to run fully interactively (no over-redirecting), so Marketplace prompts show up properly.

### v2.1.1 – More forgiving installer flow

* Handled cases where Spicetify’s installer exits with a non-zero code even though binaries are installed (e.g. due to prefs issues).
* Stopped relying purely on installer exit code; now verifies the `spicetify` binary itself.

### v2.0.0 → v2.1.0 – Big refactor

* Broke everything into functions.
* Added structured error handling and logging.
* Switched from brittle manual config edits to a more controlled approach and improved Flatpak path lookup.

### Pre-2.0.0 – The “it kinda works” era

* Simple linear script.
* Minimal checks, basic `echo` output.
* Did the job but wasn’t resilient or pleasant to use.
* This repo is the gradual story of turning that into something you can mostly trust to “just work.”

---
