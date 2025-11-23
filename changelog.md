## **📜 Changelog – spicetify.sh**

### **v2.3.3 – Permissions & Installation Order Fix**

* **Crucial Fix:** Changed the order of operations. The script now grants filesystem permissions **before** running the Spicetify installer. This prevents the "fatal: permission denied" error when the installer tries to apply patches immediately.  
* **Color Scheme:** Reset color\_scheme to auto/empty to prevent "scheme not found" warnings on fresh installs.

### **v2.3.2 – Config Polish**

* **Warning Fix:** Addressed the "Color scheme 'dark' not found" warning by ensuring the config defaults to a valid scheme or auto-detection.

### **v2.3.1 – PATH & Shell Fixes**

* **PATH Reliability:** Stopped relying on sourcing .bashrc or .zshrc to find the spicetify binary, which often failed in non-interactive modes. The script now explicitly adds \~/.spicetify to the PATH for the current session.  
* **Marketplace Fallback:** Added a manual trigger for the Marketplace installer if the main installer exits with code 127 (command not found).

### **v2.3.0 — Major Reliability Update**

A focused stability release that fixes shell-related exits, config mismatches, and Marketplace setup issues. Most users should now get a smooth **one-run installation**, even on Zsh.

* **Correct shell detection:** Uses $SHELL to avoid sourcing the wrong rc file, fixing the Zsh exit 127 issue.  
* **Safe rc sourcing:** Applies set \+e after loading shell configs to prevent user-defined options from breaking the installer.  
* **Reliable config handling:** Automatically detects and edits the correct Spicetify config file using spicetify \-c.  
* **Marketplace installs on first run:** Improved initialization ensures stable patching and consistent Marketplace setup.

### **v2.2.2 – Fixes**

* Fixed errors, script is back to working again.  
* Minor polish to keep output consistent and readable.

### **v2.2.1 – Output polish**

* Fixed some task\_detail lines to render ANSI codes exactly as intended.  
* Simplified grep checks in configure\_and\_backup\_spicetify to use grep \-Fq for path verification.

### **v2.2.0 – New output system**

* Replaced ad-hoc echo spam with structured output helpers:  
  * script\_title, section\_header, task\_running, task\_detail, task\_info,  
    task\_success, task\_warning, task\_error\_exit  
* Introduced a more consistent color scheme and layout for better readability.  
* Improved interactive prompt UX in confirm.

### **v2.1.9 – Config check robustness**

* Tightened grep patterns around config verification to better handle weird spacing.

### **v2.1.8 – Idempotent and first-run friendly**

* Always tries spicetify restore before spicetify backup apply to ensure a clean base.  
* Switched sed to use | as a delimiter to avoid conflicts with paths.  
* Verified config edits with exact string checks.

### **v2.1.7 – Sudo check fix**

* Fixed a bug in check\_sudo that could prevent the script from running.  
* Slightly improved path escaping for sed replacements.

### **v2.1.6 – The big config breakthrough**

* Guaranteed a base config-xpui.ini exists (creates a minimal one if needed).  
* Explicitly forces prefs\_path and spotify\_path into the config before running spicetify backup apply.  
* This change dramatically improved reliability with Flatpak builds.

### **v2.1.5 – Reliable Flatpak path detection**

* Switched get\_spotify\_flatpak\_paths to use:  
  flatpak info \--show-location com.spotify.Client

* Kept fallback logic for edge cases but this covers most setups cleanly.

### **v2.1.4 – Extra Flatpak debugging**

* Improved diagnostics around flatpak info when paths couldn’t be detected.  
* Helped track down several earlier bugs.

### **v2.1.3 – Path parsing improvements**

* Swapped naive parsing with gawk and proper fallbacks.  
* Added more debug lines to understand failures on different systems.

### **v2.1.2 – Interactive installer support**

* Allowed the Spicetify installer script to run fully interactively (no over-redirecting), so Marketplace prompts show up properly.

### **v2.1.1 – More forgiving installer flow**

* Handled cases where Spicetify’s installer exits with a non-zero code even though binaries are installed (e.g. due to prefs issues).  
* Stopped relying purely on installer exit code; now verifies the spicetify binary itself.

### **v2.0.0 → v2.1.0 – Big refactor**

* Broke everything into functions.  
* Added structured error handling and logging.  
* Switched from brittle manual config edits to a more controlled approach and improved Flatpak path lookup.

### **Pre-2.0.0 – The “it kinda works” era**

* Simple linear script.  
* Minimal checks, basic echo output.  
* Did the job but wasn’t resilient or pleasant to use.  
* This repo is the gradual story of turning that into something you can mostly trust to “just work.”
