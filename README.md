# 🌶️ Spicetify Flatpak Automator

### The (Mostly) Hands-Off Spicetify Installer

**One script to fix Spicetify + Flatpak headaches.** This script exists because fighting Spicetify + Flatpak can be a trial-and-error nightmare of broken paths, missing prefs, and permission quirks. The goal now is simple: you run **one script**, it does the annoying parts, and you end up with a customized Spotify + Marketplace.

If this saves you a couple of hours or some sanity, a ⭐ on GitHub is genuinely appreciated and helps keep the project polished!

[![GitHub Stars](https://img.shields.io/github/stars/boudywho/easy-spicetify-arch?style=for-the-badge&logo=github&label=Star%20Me!)](https://github.com/boudywho/easy-spicetify-arch/stargazers)  
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](./LICENSE)


---

## ✨ What Does This Do?

* **Automates Everything:** Installs dependencies, downloads the official Spicetify installer, and patches the app.
* **Smart Path Detection:** Automatically finds where Flatpak hid your Spotify installation (system or user) and wires it into Spicetify.
* **Fixes Permissions:** Handles the annoyingly complex Flatpak permission issues automatically.
* **Marketplace Ready:** Hooks into the official installer and prompts you to install the Spicetify Marketplace.
* **Safe to Re-run:** Idempotent by design. If you run it multiple times, it won’t trash your setup; it just updates or fixes things.

---

## 📦 Choose Your Distro

### ✅ Requirements (All Distros)

You must have the **Spotify Flatpak** installed from Flathub and **run it at least once**.

```bash
flatpak install flathub com.spotify.Client
flatpak run com.spotify.Client # Open once to generate config files, then close it.

```

### 🐧 Option 1: Arch Linux (Stable)

*Works with Arch, Manjaro, EndeavourOS, etc.*

1. **Clone the repository**
```bash
git clone https://github.com/boudywho/easy-spicetify-arch.git
cd easy-spicetify-arch

```


2. **Make executable and run**
```bash
chmod +x spicetify.sh
./spicetify.sh

```



### 🎩 Option 2: Fedora & Debian (Needs Testing)

*Currently in Beta. Please report any issues!*

1. Download the **Source code (zip)** from the [Latest Pre-release](https://github.com/boudywho/easy-spicetify-arch/releases/tag/v3.0.0).
2. Extract the folder and open your terminal inside it.
3. **Make executable and run**
```bash
chmod +x spicetify.sh
./spicetify.sh

```



*(Note: During installation, type `y` when asked if you want to install the Spicetify Marketplace unless you explicitly don't want it. Once finished, restart Spotify to see your changes!)*


---

## 🛠️ Troubleshooting

Most issues fall into one of these buckets:

**"Cannot detect Spotify prefs file" / `prefs_path` complaints**

> You must open Spotify at least once before running the script so it creates the necessary config files. Run `flatpak run com.spotify.Client`, close it, and run the script again.

**Permission Errors**

> The script attempts to fix these automatically (e.g., running `chmod a+wr` on the Flatpak Spotify directories). If Spicetify still complains about writing/patching, try running the script again.

**Need Help?**

> If anything looks off or half-works, open an [issue on GitHub](https://github.com/boudywho/easy-spicetify-arch/issues). Please include your script version, your distro/DE, and the **full** script output.

---

<details>
<summary><h2>🧠 Manual Installation (For Curious / Advanced Users)</h2></summary>

*You **don’t** need this if you use the script. This is just the “what the script automates for you” section.*

### 1. Install prerequisites

```bash
sudo pacman -S curl gawk --noconfirm

```

### 2. Install Spicetify CLI + Marketplace

```bash
curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh | bash

```

*Follow the prompts, and make sure `spicetify` ends up in your `PATH`.*

### 3. Find Spotify’s Flatpak paths

**Spotify install path:**

```bash
sudo flatpak info --show-location com.spotify.Client

```

The **spotify_path** is usually `<that_location>/files/extra/share/spotify` or `<that_location>/files/share/spotify`.

**Spotify prefs path:**
Usually `~/.var/app/com.spotify.Client/config/spotify/prefs`.

### 4. Configure Spicetify

Let Spicetify know where Spotify and your prefs live:

```bash
spicetify config spotify_path /your/spotify/path
spicetify config prefs_path /your/prefs/path

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

</details>

---
