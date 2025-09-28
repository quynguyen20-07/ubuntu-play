#!/usr/bin/env bash
# unity-macosify-fixed.sh — Final fixed (Ulauncher hotkey + startup sound)
set -euo pipefail
trap 'echo "[ERROR] Line $LINENO failed"; exit 1' ERR

log(){ printf "\e[1;36m[unity-macosify]\e[0m %s\n" "$*"; }
warn(){ printf "\e[1;33m[warn]\e[0m %s\n" "$*"; }
err(){ printf "\e[1;31m[err]\e[0m %s\n" "$*"; }

# 0. Quick check for Unity (warn but continue)
XDESK="${XDG_CURRENT_DESKTOP:-}"
if ! echo "$XDESK" | grep -iq "Unity"; then
  warn "XDG_CURRENT_DESKTOP='$XDESK' — script written for Unity but will try to proceed."
fi
log "Detected desktop: $XDESK"

# 1. Install essentials (idempotent)
log "Installing base packages..."
sudo add-apt-repository -y ppa:agornostal/ulauncher >/dev/null 2>&1 || true
sudo apt-get update -y
sudo apt-get install -y \
  git curl wget unzip p7zip-full xz-utils wmctrl xdotool \
  plank gnome-tweaks papirus-icon-theme fonts-firacode fonts-noto-core || true

# Install ulauncher if missing
if ! dpkg -s ulauncher >/dev/null 2>&1; then
  log "Installing Ulauncher from PPA..."
  sudo apt-get install -y ulauncher || true
else
  log "Ulauncher already installed"
fi

# 2. Hide Unity launcher (keep as fallback)
log "Hiding Unity launcher (autohide)..."
dconf write /com/canonical/unity/launcher/launcher-hide-mode 1 || true
gsettings set com.canonical.Unity.Launcher hide-mode 1 2>/dev/null || true

# 3. Plank autostart + config
log "Configuring Plank (autostart + magnify)..."
mkdir -p "$HOME/.config/autostart" "$HOME/.config/plank/dock1"
cat > "$HOME/.config/autostart/plank.desktop" <<'PLANKDESK'
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
X-GNOME-Autostart-enabled=true
Name=Plank
PLANKDESK

cat > "$HOME/.config/plank/dock1/settings" <<'PLANKCFG'
[PlankDockPreferences]
Position=bottom
IconSize=48
ZoomEnabled=true
ZoomPercent=120
HideMode=1
PLANKCFG

# start plank if not running
if ! pgrep -x plank >/dev/null 2>&1; then
  (plank &) || true
fi

# 4. Install WhiteSur (Sequoia-like) theme/icons (clean previous clones)
log "Installing WhiteSur theme & icons..."
TMP=/tmp/unity-macosify
rm -rf "$TMP"
mkdir -p "$TMP"
cd "$TMP"
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git || true
if [[ -d WhiteSur-gtk-theme ]]; then
  pushd WhiteSur-gtk-theme >/dev/null
  ./install.sh -d "$HOME/.themes" -l || true
  popd >/dev/null
fi
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git || true
if [[ -d WhiteSur-icon-theme ]]; then
  pushd WhiteSur-icon-theme >/dev/null
  ./install.sh -d "$HOME/.icons" -a || true
  popd >/dev/null
fi
# cursors
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git || true
if [[ -d WhiteSur-cursors ]]; then
  pushd WhiteSur-cursors >/dev/null
  ./install.sh -d "$HOME/.icons" || true
  popd >/dev/null
fi

# apply themes (GTK apps)
log "Applying GTK theme and icons..."
gsettings set org.gnome.desktop.interface gtk-theme "WhiteSur-Dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme "WhiteSur-dark" 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme "WhiteSur-cursors" 2>/dev/null || true
gsettings set org.gnome.shell.extensions.user-theme name "WhiteSur-Dark" 2>/dev/null || true

# 5. Rounded corners CSS
log "Adding GTK rounded-corners tweaks..."
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-3.0/gtk.css" <<'GTK3'
.window, .window-frame, GtkWindow {
  border-radius: 12px;
  overflow: hidden;
}
GTK3
cat > "$HOME/.config/gtk-4.0/gtk.css" <<'GTK4'
.window, GtkWindow {
  border-radius: 12px;
}
GTK4

# 6. Fonts: try a few sources; if you have a legal SF Pro ZIP use --font-zip manual step
log "Installing fonts (attempt SF-Pro then fallback)..."
# attempt: try some known mirrors (best-effort), else fallback to system fonts
cd /tmp
rm -rf /tmp/sfprozip
# try github mirror first (many community mirrors exist)
if wget -q -O /tmp/sfprozip.zip "https://codeload.github.com/sahibjotsaggu/San-Francisco-Pro-Fonts/zip/refs/heads/master"; then
  unzip -q /tmp/sfprozip.zip -d /tmp/sfprozip || true
  find /tmp/sfprozip -type f \( -iname "*.otf" -o -iname "*.ttf" \) -exec cp -v {} "$HOME/.local/share/fonts/" \; || true
  fc-cache -fv >/dev/null 2>&1 || true
else
  warn "Could not fetch SF Pro from mirror — installing fallback fonts"
  sudo apt-get install -y fonts-noto fonts-firacode || true
  fc-cache -fv >/dev/null 2>&1 || true
fi

# 7. Ulauncher autostart + robust hotkey via custom keybinding (works even if Ulauncher schema missing)
log "Configuring Ulauncher autostart and creating custom hotkey (Super+Space)..."
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/ulauncher.desktop" <<'ULAD'
[Desktop Entry]
Type=Application
Name=Ulauncher
Exec=ulauncher --hide-window
X-GNOME-Autostart-enabled=true
ULAD

# try to start Ulauncher in background to warm caches (do not kill it)
if ! pgrep -x ulauncher >/dev/null 2>&1; then
  (ulauncher >/dev/null 2>&1 &)
  sleep 2
fi

# Add a custom keybinding that launches/toggles Ulauncher
CB_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ulauncher/"
# read existing list
CUR=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo "@as []")
if ! echo "$CUR" | grep -q "$CB_PATH"; then
  if [[ "$CUR" == "@as []" ]]; then
    NEW="['$CB_PATH']"
  else
    NEW=$(echo "$CUR" | sed "s/]$/, '$CB_PATH']/")
  fi
  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW" 2>/dev/null || true
fi
# set the custom binding keys
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$CB_PATH name 'Ulauncher' 2>/dev/null || true
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$CB_PATH command 'ulauncher --hide-window' 2>/dev/null || true
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$CB_PATH binding '<Super>space' 2>/dev/null || true

log "Custom hotkey set: Super+Space → Ulauncher (if your desktop honors GNOME custom keys)."

# 8. macOS-like startup sound: generate local WAV via python (no external download)
log "Creating small startup sound locally (Python-generated sine tone)..."
mkdir -p "$HOME/.config/systemd/user"
START_WAV="$HOME/.config/systemd/user/macos-startup.wav"
python3 - <<'PY' || true
import wave, struct, math, os
out = os.path.expanduser("~/.config/systemd/user/macos-startup.wav")
fr = 44100
dur = 0.55
f0 = 783.99  # A5-ish tone
amp = 16000
n = int(fr * dur)
with wave.open(out, 'w') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(fr)
    for i in range(n):
        v = int(amp * math.sin(2*math.pi*f0*i/fr) * (1 - i/n))
        w.writeframes(struct.pack('<h', v))
PY
# create systemd user service to play it (one-shot)
cat > "$HOME/.config/systemd/user/macos-startup.service" <<'SVC'
[Unit]
Description=Play macOS-like startup sound (user)

[Service]
Type=oneshot
ExecStart=/usr/bin/aplay ~/.config/systemd/user/macos-startup.wav

[Install]
WantedBy=default.target
SVC
# enable it (best-effort)
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now macos-startup.service 2>/dev/null || warn "Could not enable macos-startup.service (systemctl --user may not be active now)."

# 9. Dynamic wallpaper (simple skeleton)
log "Installing dynamic wallpaper skeleton (Sequoia sample)..."
mkdir -p "$HOME/Pictures/Wallpapers/sequoia"
SAMPLE="$HOME/Pictures/Wallpapers/sequoia/sequoia_dynamic.jpg"
if [[ ! -f "$SAMPLE" ]]; then
  wget -q -O "$SAMPLE" "https://raw.githubusercontent.com/adi1090x/dynamic-wallpaper/master/macOS/BigSur/DayNight.jpg" || true
fi
# apply once (GNOME settings; Unity may or may not honor)
gsettings set org.gnome.desktop.background picture-uri "file://$SAMPLE" 2>/dev/null || true

# final
log "DONE — basic macOS Sequoia look applied to Unity."
cat <<EOF

Notes:
 - RELAUNCH: Log out and log back in (or reboot) to see theme + shell fully applied.
 - If the Super+Space shortcut doesn't work immediately, open Settings -> Keyboard -> Shortcuts
   and check Custom Shortcuts; the "Ulauncher" binding should exist (command: ulauncher --hide-window).
 - If you want the exact SF Pro fonts and you have a legal ZIP, place it somewhere and run:
     unzip /path/to/SF-Pro.zip -d /tmp && cp /tmp/**/*.otf ~/.local/share/fonts/ && fc-cache -f
 - If you want Genie/minimize animation (Compiz magic-lamp), say so and I'll add it (fragile).
EOF
