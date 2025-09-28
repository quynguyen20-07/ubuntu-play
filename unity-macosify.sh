#!/usr/bin/env bash
# unity-macosify.sh — macOS Sequoia Style for Ubuntu Unity Desktop (22.04+)

set -euo pipefail

log() { echo -e "\e[1;36m[unity-macosify]\e[0m $*"; }
err() { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; }

# 0. Check Desktop
if [[ "${XDG_CURRENT_DESKTOP:-}" != *"Unity"* ]]; then
  err "Không phải Unity Desktop! Đăng xuất → ở màn hình đăng nhập → chọn 'Unity'."
  exit 1
fi

log "✅ Unity Desktop detected"

# 1. Install Essentials
log "📦 Installing packages..."
sudo add-apt-repository -y ppa:agornostal/ulauncher
sudo apt update
sudo apt install -y plank gnome-tweaks curl wget unzip ulauncher papirus-icon-theme

# 2. Hide Unity Dock
log "🚫 Hiding Unity default dock..."
dconf write /com/canonical/unity/launcher/launcher-hide-mode 1 || true

# 3. Enable Plank autostart
log "⚓ Enabling Plank autostart..."
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/plank.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
X-GNOME-Autostart-enabled=true
Name=Plank
EOF

# 4. Configure Plank Dock
log "⚙️ Configuring Plank (magnify like macOS)..."
PLANK_CFG="$HOME/.config/plank"
mkdir -p "$PLANK_CFG/dock1"
cat > "$PLANK_CFG/dock1/settings" <<EOF
[PlankDockPreferences]
Position=bottom
IconSize=48
ZoomEnabled=true
ZoomPercent=120
HideMode=1
EOF

# 5. Theme macOS Sequoia (WhiteSur Dark)
log "🎨 Installing macOS Sequoia Theme..."
THEME_DIR="$HOME/.themes"
ICON_DIR="$HOME/.icons"
mkdir -p "$THEME_DIR" "$ICON_DIR"
cd /tmp

git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git
cd WhiteSur-gtk-theme
./install.sh -d "$THEME_DIR" -l

cd /tmp
git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git
cd WhiteSur-icon-theme
./install.sh -d "$ICON_DIR" -a

gsettings set org.gnome.desktop.interface gtk-theme "WhiteSur-Dark"
gsettings set org.gnome.desktop.interface icon-theme "WhiteSur-dark"
gsettings set org.gnome.desktop.interface cursor-theme "WhiteSur-cursors"

# 6. Install SF Pro System Font
log "🔤 Installing SF Pro Fonts..."
cd /tmp
wget -O sfpro.zip "https://github.com/sahibjotsaggu/SF-Pro-Fonts/archive/refs/heads/master.zip"
unzip sfpro.zip -d sfpro
mkdir -p ~/.local/share/fonts
cp sfpro/*/*.otf ~/.local/share/fonts/
fc-cache -fv

# 7. Ulauncher Spotlight
log "🔎 Configuring Spotlight (Ulauncher = CMD+SPACE)..."
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/ulauncher.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Ulauncher
Exec=ulauncher --hide-window
X-GNOME-Autostart-enabled=true
EOF

gsettings set com.github.ulauncher hotkey "<Super>space"

# 8. macOS Startup Sound
log "🔊 Adding macOS startup sound..."
mkdir -p ~/.config/systemd/user
wget -O ~/.config/systemd/user/macos-startup.wav "https://cdn.pixabay.com/download/audio/2022/03/15/audio_5b4b9f96f8.wav"
cat > ~/.config/systemd/user/macos-startup.service <<EOF
[Unit]
Description=macOS Startup Sound

[Service]
ExecStart=/usr/bin/aplay ~/.config/systemd/user/macos-startup.wav

[Install]
WantedBy=default.target
EOF
systemctl --user enable macos-startup.service

# 9. Dynamic Wallpaper
log "🌓 Installing Dynamic Wallpaper..."
sudo apt install -y gsettings-desktop-schemas
mkdir -p ~/Pictures/Wallpapers
wget -O ~/Pictures/Wallpapers/sequoia_dynamic.jpg "https://raw.githubusercontent.com/adi1090x/dynamic-wallpaper/master/macOS/BigSur/DayNight.jpg"
gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Pictures/Wallpapers/sequoia_dynamic.jpg"

log "✅ macOS Sequoia Unity setup complete!"
echo -e "\n🔁 Khởi động lại máy hoặc Log out để xem hiệu ứng hoàn chỉnh!"
