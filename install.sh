#!/bin/bash

# Nosrednawall - DWM Setup
# https://github.com/nosrednawall/dwm-setup

set -e

# Command line options
ONLY_CONFIG=false
EXPORT_PACKAGES=false
INSTALL_NVIDIA=false
INSTALL_AMD=false
INSTALL_INTEL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --only-config)
            ONLY_CONFIG=true
            shift
            ;;
        --export-packages)
            EXPORT_PACKAGES=true
            shift
            ;;
        --gpu)
            if [[ $# -gt 1  ]]; then
                case $2 in
                    nvidia)
                        INSTALL_NVIDIA=true
                    ;;
                    amd)
                        INSTALL_AMD=true
                    ;;
                    intel)
                        INSTALL_INTEL=true
                    ;;
                    *)
                        echo "Error: Invalid GPU type '$2'. Use: nvidia, amd, intel "
                        exit 1
                        ;;
                esac
                shift 2
            else
                echo "Error: --gpu requires an argument"
                exit 1
            fi
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "  --only-config      Only copy config files (skip packages and external tools)"
            echo "  --export-packages  Export package lists for different distros and exit"
            echo "  --gpu nvidia       Install suport for NVIDIA hardware"
            echo "  --gpu amd          Install suport for AMD hardware"
            echo "  --gpu intel        Install suport for INTEL hardware"
            echo "  --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/suckless"
TEMP_DIR="/tmp/dwm_$$"
LOG_FILE="$HOME/dwm-install.log"

# Logging and cleanup
exec > >(tee -a "$LOG_FILE") 2>&1
trap "rm -rf $TEMP_DIR" EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
msg() { echo -e "${CYAN}$*${NC}"; }

# Export package lists for different distros
export_packages() {
    echo "=== DWM Setup - Package Lists for Different Distributions ==="
    echo
    
    # Combine all packages
    local all_packages=(
        "${PACKAGES_CORE[@]}"
        "${PACKAGES_UI[@]}"
        "${PACKAGES_FILE_MANAGER[@]}"
        "${PACKAGES_AUDIO[@]}"
        "${PACKAGES_UTILITIES[@]}"
        "${PACKAGES_TERMINAL[@]}"
        "${PACKAGES_FONTS[@]}"
        "${PACKAGES_BUILD[@]}"
    )
    
    echo "Arch Linux:"
    echo "sudo apt install ${all_packages[*]}"
    echo

    # Fedora equivalents
    local fedora_packages=(
        "xorg-x11-server-Xorg xorg-x11-xinit xbacklight xbindkeys xvkbd xinput"
        "gcc make git sxhkd xdotool"
        "libnotify"
        "rofi dunst feh lxappearance NetworkManager-gnome"
        "thunar thunar-archive-plugin thunar-volman"
        "gvfs dialog mtools samba-client cifs-utils unzip"
        "pavucontrol pulsemixer pamixer pipewire-pulseaudio"
        "avahi acpi acpid xfce4-power-manager flameshot"
        "qimgv firefox xdg-user-dirs-gtk"
        "eza"
        "fontawesome-fonts terminus-fonts"
        "cmake meson ninja-build curl pkgconfig"
    )
    
    echo "FEDORA:"
    echo "sudo dnf install ${fedora_packages[*]}"
    echo
    
    echo "NOTE: Some packages may have different names or may not be available"
    echo "in all distributions. You may need to:"
    echo "  - Find equivalent packages in your distro's repositories"
    echo "  - Install some tools from source (like suckless tools)"
    echo "  - Use alternative package managers (AUR for Arch, Flatpak, etc.)"
    echo
    echo "After installing packages, you can use:"
    echo "  $0 --only-config    # To copy just the DWM configuration files"
}

install_yay() {
    local temp_dir="/tmp/yay"

    # Limpa e clona
    sudo rm -rf "$temp_dir"
    git clone https://aur.archlinux.org/yay.git "$temp_dir"

    # Executa makepkg sem mudar de diretório
    makepkg -p "$temp_dir/PKGBUILD" -si --noconfirm
}

install_drivers_nvidia() {
    echo "Instalando drivers nvidia..."
    # Driver Nvidia
    sudo pacman -S --noconfirm nvidia-dkms egl-wayland lib32-nvidia-utils lib32-opencl-nvidia nvidia-settings opencl-nvidia \
        nvidia-utils libnvidia-container mesa xf86-video-amdgpu nvtop

    # Control prime
    yay -S --noconfirm envycontrol
}

# Drivers AMD
install_drivers_amd() {
    echo "Instalando drivers AMD completos..."
    sudo pacman -S --noconfirm \
        mesa \
        vulkan-radeon \
        lib32-mesa \
        lib32-vulkan-radeon \
        xf86-video-amdgpu \
        amd-ucode \
        libva-mesa-driver \
        mesa-vdpau \
        nvtop \
        vulkan-icd-loader \
        lib32-vulkan-icd-loader \
        vdpauinfo \
        vainfo \
        rocm-opencl-runtime clinfo
}

# Drivers Intel
install_drivers_intel() {
    echo "Instalando drivers Intel completos..."
    sudo pacman -S --noconfirm \
        mesa \
        vulkan-intel \
        lib32-mesa \
        lib32-vulkan-intel \
        xf86-video-intel \
        intel-ucode \
        libva-intel-driver \
        intel-media-driver \
        nvtop \
        vulkan-icd-loader \
        lib32-vulkan-icd-loader \
        vdpauinfo \
        vainfo
}

install_virt_manager(){

    # Virt-manager - Fonte https://computingpost.medium.com/install-kvm-qemu-and-virt-manager-on-arch-linux-manjaro-d464caee0fd3
    sudo pacman -S --noconfirm qemu-full virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libvirt mesa-utils
    sudo pacman -S --noconfirm iptables-nft dnsmasq
    sudo pacman -S --noconfirm libguestfs

    # Ativa serviços
    sudo systemctl enable iptables.service
    sudo systemctl enable libvirtd.service
    sudo systemctl enable libvirtd.socket

    # Altera permissoes
    sudo sed -i 's/^#\(unix_sock_group = "libvirt"\)/\1/' /etc/libvirt/libvirtd.conf
    sudo sed -i 's/^#\(unix_sock_rw_perms = "0777"\)/\1/' /etc/libvirt/libvirtd.conf

    # Adiciona no grupo
    sudo usermod -a -G libvirt $(whoami)
    # sudo gpasswd -a anderson libvirt
    newgrp libvirt

	# reinicie o computador ***
}

install_oh_my_bash() {
    echo "Instalando Oh My Bash silenciosamente..."

    # Executa em modo não-interativo
    RUNBASH=no bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" <<EOF
n
EOF

    echo "Instalação completa. Execute 'source ~/.bashrc' para carregar."
}

# Emacs e Doom
install_emacs(){
    # emacs and doom emacs
    #yay -S --noconfirm emacs-lucid  ## EMacs lucid - vai levar um século para compilar
    sudo pacman -S --noconfirm emacs ripgrep fd findutils
    git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
    ~/.config/emacs/bin/doom install
}

extract_dotfiles_tar() {
    local dotfiles_dir="$CONFIG_DIR/dotfiles"

    echo "Extraindo todos os arquivos tar.gz para $HOME..."

    # Encontra e extrai todos os tar.gz recursivamente
    find "$dotfiles_dir" -name "*.tar.gz" -type f -exec echo "Extraindo: {}" \; -exec tar -xzf {} -C "$HOME" --overwrite \;

    echo "Extração completa!"
}

# Install dotfiles
install_dotfiles() {
    local folders_dotfiles=(
        bmks conky mpd newsboat ranger solaar wallpapers
        btop doom home ncmpcpp picom rofi sxhkd wireplumber
        calcurse dunst neofetch qt5ct scripts
    )

    for folder in "${folders_dotfiles[@]}"; do
        local folder_path="$CONFIG_DIR/dotfiles/$folder"

        if [[ ! -d "$folder_path" ]]; then
            echo "Aviso: Pasta $folder não encontrada em $folder_path, pulando..."
            continue
        fi

        echo "Instalando dotfiles: $folder"
        # Usa -d para especificar o diretório do pacote stow
        stow -d "$CONFIG_DIR/dotfiles" -t "$HOME" "$folder" || echo "Erro no stow para $folder"
    done

    echo "Dotfiles instalados com sucesso!"
}


# Check if we should export packages and exit
if [ "$EXPORT_PACKAGES" = true ]; then
    export_packages
    exit 0
fi

# Banner
clear
echo -e "${CYAN}"
echo " +-+-+-+-+-+-+-+-+-+-+-+-+-+ "
echo " |n|o|s|r|e|d|n|a|w|a|l|l| "
echo " +-+-+-+-+-+-+-+-+-+-+-+-+-+ "
echo " |d|w|m| |s|e|t|u|p|        | "
echo " +-+-+-+-+-+-+-+-+-+-+-+-+-+ "
echo -e "${NC}\n"

read -p "Install DWM? (y/n) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 1

# Update system
if [ "$ONLY_CONFIG" = false ]; then
    msg "Updating system..."
    sudo pacman -Syuv --noconfirm
else
    msg "Skipping system update (--only-config mode)"
fi

# Package groups for better organization
PACKAGES_CORE=(
    xorg-server xorg-xsetroot xf86-input-wacom libwacom i2c-tools networkmanager
    libnotify ripgrep fd findutils lxsession pacman-contrib less xdg-user-dirs
    sxhkd pv arandr jq bc gnupg xdotool git git-lfs stow base-devel linux-headers
    nano linux-firmware inotify-tools go wget dosfstools ntfsprogs ly flatpak
    timeshift grub-btrfs
)

PACKAGES_UI=(
    picom rofi dunst copyq pinentry pasystray solaar flameshot btop gpicview calcurse
    firefox firefox-i18n-pt-br firefoxpwa pulsemixer geany newsboat sxiv syncthing
)

PACKAGES_FILE_MANAGER=(
    thunar ranger thunar-archive-plugin thunar-media-tags-plugin udisks2 smbclient
    samba gvfs gvfs-smb cifs-utils xarchiver cpio unarj unzip zip unace unrar p7zip
    sharutils uudeview arj cabextract lzip zlib laszip lbzip2 lrzip pbzip2 lzop
    tumbler ffmpegthumbnailer thunar-shares-plugin thunar-vcs-plugin thunar-volman
)

PACKAGES_AUDIO=(
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol alsa-utils
)

PACKAGES_UTILITIES=(
    papirus-icon-theme lxappearance qt5ct bluez bluez-tools
    bluez-utils blueman ffmpeg gst-plugins-ugly gst-plugins-good gst-plugins-base
    gst-plugins-bad gst-libav gstreamer mpv vlc vlc-plugins-all ueberzugpp mpv-mpris
    libreoffice-fresh libreoffice-fresh-pt-br aspell-pt atril xournalpp qalculate-gtk
    gthumb thunderbird thunderbird-i18n-pt-br
)

PACKAGES_TERMINAL=(
    curl htop feh python-oauth2client python-httplib2 conky brightnessctl redshift
    playerctl mpd ncmpcpp mpc mpd-mpris rmpc slop pass qtpass pinentry xclip bitwarden-cli
    wireguard-tools systemd-resolvconf tailscale
)

PACKAGES_FONTS=(
    cabextract fontconfig ttf-dejavu ttf-ubuntu-font-family ttf-roboto
    noto-fonts-cjk noto-fonts-emoji noto-fonts
)

PACKAGES_BUILD=(
    make gcc libx11 libxft libxinerama harfbuzz imlib2 libxrandr
    libxcb libx11 xcb-util gd gtk-engine-murrine xsettingsd libpillowfight
    python-pillow-heif python-pillowfight python-pyscreenshot python-gobject
)

PACKAGES_YAY=(
    python-pywal16 wpgtk-git c3-bin numix-icon-theme-git xwinwrap-git cava gnome-ssh-askpass3
    nordvpn-bin google-chrome syncthingtray timeshift-autosnap  ttf-ms-fonts nerd-fonts-noto
)

PACKAGES_FLATPAK=(
    com.bitwarden.desktop com.github.tchx84.Flatseal
    io.dbeaver.DBeaverCommunity io.freetubeapp.FreeTube io.github.flattool.Warehouse
    md.obsidian.Obsidian org.filezillaproject.Filezilla
)

PACKAGES_DOCKER=(
    docker docker-compose
)

# Install packages by group
if [ "$ONLY_CONFIG" = false ]; then
    msg "Installing core packages..."
    sudo pacman -S --noconfirm "${PACKAGES_CORE[@]}" || die "Failed to install core packages"

    msg "Installing UI components..."
    sudo pacman -S --noconfirm "${PACKAGES_UI[@]}" || die "Failed to install UI packages"

    msg "Installing file manager..."
    sudo pacman -S --noconfirm "${PACKAGES_FILE_MANAGER[@]}" || die "Failed to install file manager"

    msg "Installing audio support..."
    sudo pacman -S --noconfirm "${PACKAGES_AUDIO[@]}" || die "Failed to install audio packages"

    msg "Installing system utilities..."
    sudo pacman -S --noconfirm "${PACKAGES_UTILITIES[@]}" || die "Failed to install utilities"

    msg "Installing terminal tools..."
    sudo pacman -S --noconfirm "${PACKAGES_TERMINAL[@]}" || die "Failed to install terminal tools"

    msg "Installing fonts..."
    sudo pacman -S --noconfirm "${PACKAGES_FONTS[@]}" || die "Failed to install fonts"

    msg "Installing build dependencies..."
    sudo pacman -S --noconfirm "${PACKAGES_BUILD[@]}" || die "Failed to install build tools"

    msg "Installing yay..."
    install_yay || die "Failed to install yay"

    msg "Installing yay packages..."
    yay -S --noconfirm "${PACKAGES_YAY[@]}" || die "Failed to install yay programs"

    msg "Add flatpak repository..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    msg "Installing flatpak packages..."
    flatpak install "${PACKAGES_FLATPAK[@]}" -y || die "Failed to install flatpaks programs"

    msg "Installing emacs..."
    install_emacs || die "Failed to install emacs"

    msg "Installing docker..."
    sudo pacman -S --noconfirm "${PACKAGES_DOCKER[@]}" || die "Failed to install docker"

    msg "Installing Oh My Bash..."
    install_oh_my_bash || die "Failed to install docker"

    echo -e "Deseja intalar o Virt-manager?\n\nEscolha:\n1-sim\n0-Nao\n"
    read escolha

    if [ $escolha = "1" ]; then
        install_virt_manager
    fi



    # Enable services
    sudo systemctl enable NetworkManager.service docker.service nordvpnd.service ly.service grub-btrfsd

    # Disable automatic services
    sudo systemctl disable mpd

    # Enable services for user
    systemctl --user enable mpd mpd-mpris

    # Configure properties user
    sudo usermod -aG docker $USER
    sudo usermod -aG nordvpn $USER
else
    msg "Skipping package installation (--only-config mode)"
fi

# Handle existing config
if [ -d "$CONFIG_DIR" ]; then
    clear
    read -p "Found existing suckless config. Backup? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv "$CONFIG_DIR" "$CONFIG_DIR.bak.$(date +%s)"
        msg "Backed up existing config"
    else
        clear
        read -p "Overwrite without backup? (y/n) " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || die "Installation cancelled"
        rm -rf "$CONFIG_DIR"
    fi
fi

# Copy configs
msg "Setting up configuration..."
mkdir -p "$CONFIG_DIR"
cp -r "$SCRIPT_DIR"/suckless/* "$CONFIG_DIR"/ || die "Failed to copy configs"

# Build suckless tools
msg "Building suckless tools..."
for tool in dwm dwmblocks-async st slock potato-c tabbed; do
    cd "$CONFIG_DIR/$tool" || die "Cannot find $tool"
    make && sudo make install || die "Failed to build $tool"
done

# Create desktop entry for DWM
sudo mkdir -p /usr/share/xsessions
cat <<EOF | sudo tee /usr/share/xsessions/dwm.desktop >/dev/null
[Desktop Entry]
Name=dwm
Comment=Dynamic window manager
Exec=dwm
Type=XSession
EOF

# Create desktop file for ST
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/st.desktop << EOF
[Desktop Entry]
Name=st
Comment=Simple Terminal
Exec=st
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
EOF

# Configure st icon
sudo mkdir -p /usr/local/share/pixmaps/
sudo cp "$CONFIG_DIR/st/st.png" /usr/local/share/pixmaps/st.png

# Configure wallpaper slock
sudo mkdir -p /usr/share/images/desktop-base
sudo cp "$CONFIG_DIR/slock/wallpaper.jpg" /usr/share/images/desktop-base/wallpaper-slock

# Setup directories
xdg-user-dirs-update
mkdir -p /home/$USER/{Desktop,Downloads,Documentos,git,Imagens/Screenshoots,Músicas,.lyrics,.programas,.appimage, .local/bin}

# Configs open images with sxiv
xdg-mime default sxiv.desktop image/png
xdg-mime default sxiv.desktop image/jpeg
xdg-mime default sxiv.desktop image/jpg
xdg-mime default sxiv.desktop image/gif
xdg-mime default sxiv.desktop image/svg+xml

# Remove warning for console font
echo "configure console font"
echo "FONT=lat9w-16" | sudo tee -a /etc/vconsole.conf

echo "Install dotfiles..."
install_dotfiles

echo "Extract fonts, icons and themes"
extract_dotfiles_tar
fc-cache -fvr

# Themes for wpg
wpg-install.sh -gi # baixa os temas
ln -s /home/$USER/.local/share/icons/flattrcolor .icons/
ln -s /home/$USER/.local/share/icons/flattrcolor-dark/ .icons/

# Files for themes
cat > ~/.theme_selected << EOF
#!/bin/bash
THEME_GTK="Gruvbox-Material-Dark"
THEME_ICON="Numix-Circle"
THEME_MODE="Gruvbox"
COLOR_MODE="Dark"
COLOR_BACKGROUND="#282828"
COLOR_BACKGROUND2="#3c3836"
COLOR_TEXT="#ebdbb2"
COLOR_1="#d79921"     # Pink
COLOR_2="#fe8019"     # Purple
COLOR_3="#fb4934"     # Light Red
COLOR_4="#d3869b"     # Magenta
COLOR_5="#83a598"     # Light Blue
COLOR_6="#8ec07c"     # Cyan
COLOR_7="#b8bb26"     # Light Green
COLOR_8="#928374"     # Light Gray
COLOR_9="#f2c76e"     # Pink
COLOR_10="#ffa347"   # Purple
COLOR_11="#ff6e5a"   # Light Red
COLOR_12="#e9aec5"   # Magenta
COLOR_13="#a7c7d4"   # Light Blue
COLOR_14="#b0d9a1"   # Cyan
COLOR_15="#d5d85c"   # Light Green
COLOR_16="#b5aa99"   # Light Gray
EOF

cat > ~/.cache/dwmblocks_modo_operacao << EOF
#!/bin/bash
OPERATION_MODE="COMPLETO"
THEME="icon-color"
EOF

cat > ~/.cache/dwmblocks_weather_mode << EOF
#!/bin/bash
WEATHER_MODE="HIDE"
EOF

mkdir -p ~/.config/gtk-2.0/
cat > ~/.config/gtk-2.0/gtkrc << EOF
gtk-icon-theme-name = "Numix-Circle"
gtk-theme-name = "Gruvbox-Material-Dark"
EOF

mkdir -p  ~/.config/gtk-3.0/
cat >  ~/.config/gtk-3.0/settings.ini << EOF
[Settings]
gtk-theme-name=Gruvbox-Material-Dark
gtk-icon-theme-name=Numix-Circle
gtk-font-name=Sans 10
gtk-cursor-theme-name=capitaine-cursors-gruvbox-white
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
gtk-xft-rgba=none
gtk-application-prefer-dark-theme=1
EOF

cat >  ~/.gtkrc-2.0 << EOF
# DO NOT EDIT! This file will be overwritten by LXAppearance.
# Any customization should be done in ~/.gtkrc-2.0.mine instead.

include "/home/anderson/.gtkrc-2.0.mine"
gtk-theme-name="Gruvbox-Material-Dark"
gtk-icon-theme-name="Numix-Circle"
gtk-font-name="Sans 10"
gtk-cursor-theme-name=capitaine-cursors-gruvbox-white
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintfull"
EOF

# Configura o sensors para o dwmblocks
yes | sudo sensors-detect

# Configura o navegador padrao
sudo ln -s $(which firefox) /usr/bin/x-www-browser
#sudo ln -s /opt/google/chrome/google-chrome /usr/bin/x-www-browser

# Configuracoes do git
cd ~
git config --global user.email "nosrednawall@gmail.com"
git config --global user.name "nosrednawall"

# SSH
ssh-keygen -t ed25519 -C "nosrednawall@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Grupos
sudo usermod -aG users,audio,video,input,storage,optical,power,network,scanner $(whoami)

# Done
echo -e "\n${GREEN}Installation complete!${NC}"
echo "1. Log out and select 'dwm' from your display manager"
echo "2. Press Super+H for keybindings"
