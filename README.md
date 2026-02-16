# 🌶️ Spicetify Flatpak Automator

**One script to fix Spicetify + Flatpak headaches.**
Automate the installation of Spicetify, fix permissions, and setup the Marketplace on your Spotify Flatpak.

---

## 📦 Choose Your Distro

### ✅ Requirements (All Distros)

You must have the **Spotify Flatpak** installed and run at least once.

```bash
flatpak install flathub com.spotify.Client
flatpak run com.spotify.Client # Open once to generate config files, then close it.

```

### 🐧 Option 1: Arch Linux (Stable)

*Works with Arch, Manjaro, EndeavourOS, etc.*

```bash
# 1. Clone the repository
git clone https://github.com/boudywho/easy-spicetify-arch.git
cd easy-spicetify-arch

# 2. Make executable
chmod +x spicetify.sh

# 3. Run
./spicetify.sh

```

### 🎩 Option 2: Fedora & Debian (Needs Testing)

*Currently in Beta. Please report any issues!*

1. Download the **Source code (zip)** from the [Latest Pre-release](https://github.com/boudywho/easy-spicetify-arch/releases/tag/v3.0.0).
2. Extract the folder and open your terminal inside it.
3. Run the following:

```bash
# 1. Make executable
chmod +x spicetify.sh

# 2. Run
./spicetify.sh

```

---

## ✨ What does this do?

* **Automates Everything:** Downloads Spicetify, installs dependencies, and patches the app.
* **Finds Paths:** Automatically detects where Flatpak hid your Spotify installation.
* **Fixes Permissions:** Handles the annoyingly complex Flatpak permission issues for you.
* **Marketplace:** Prompts you to install the Spicetify Marketplace automatically.

---

## 🛠️ Troubleshooting

**"Cannot detect Spotify prefs file"**

> You must open Spotify at least once before running the script so it creates the necessary config files.

**Permission Errors**

> The script tries to fix these automatically. If it fails, try running the script again, check the issues tab or report the [issue](https://github.com/boudywho/easy-spicetify-arch/issues) yourself :).
