#!/bin/bash
set -ouex pipefail

### 1. REPO SETUP & PACKAGES
dnf5 -y install dnf5-plugins
dnf5 config-manager setopt fedora-cisco-openh264.enabled=1
dnf5 copr enable -y bieszczaders/kernel-cachyos
dnf5 copr enable -y bieszczaders/kernel-cachyos-addons
dnf5 config-manager setopt keepcache=1
dnf5 config-manager setopt install_weak_deps=0
dnf5 -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm dnf5-plugins

# Install Base + CachyOS + UKI Tools
# Removed invisible characters from your previous snippet
dnf5 install -y \
    kakoune fish f2fs-tools composefs \
    gdm gnome-shell flatpak ananicy-cpp \
    mesa-dri-drivers systemd-boot xdg-desktop-portal-gnome \
    xdg-user-dirs-gtk iwd systemd-resolved \
    pipewire wireplumber NetworkManager-wifi \
    plymouth libcap-ng libcap-ng-devel \
    procps-ng procps-ng-devel uksmd \
    systemd-ukify binutils sbsigntools \
    kernel-cachyos kernel-cachyos-modules kernel-cachyos-core

# Remove Stock Kernel
dnf5 remove -y kernel kernel-core kernel-modules

### 2. CONFIGURATION (Must happen BEFORE kernel build)
# Network
mkdir -p /etc/NetworkManager/conf.d
echo -e "[device]\nwifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf

# Bootc / ComposeFS
mkdir -p /etc/default
echo "STORAGE_DRIVER=composefs" >> /etc/default/bootc

# Dracut modules
mkdir -p /etc/dracut.conf.d
echo 'add_dracutmodules+=" f2fs "' > /etc/dracut.conf.d/f2fs.conf

# Kernel Layout
mkdir -p /etc/kernel
echo "layout=uki" > /etc/kernel/install.conf

# Kernel Command Line
# IMPORTANT: ComposeFS validation happens here
echo "composefs=1 rootfstype=f2fs rw preempt=full quiet rhgb" > /etc/kernel/cmdline

### 3. MANUAL UKI BUILD (Bypasses rpm-ostree error)
# Find the CachyOS version
KERNEL_VER=$(ls /usr/lib/modules | grep cachy | head -n 1)
echo "Building UKI for Kernel: $KERNEL_VER"

# A. Generate Initramfs to a temp location
# We skip the standard install to avoid the 'cross-device link' error
dracut -vf "/tmp/initramfs-${KERNEL_VER}.img" --kver "$KERNEL_VER"

# B. Build the Unified Kernel Image (UKI)
# This bundles Kernel + Initramfs + Cmdline + Splashes
mkdir -p /boot/EFI/Linux
ukify build \
    --linux "/usr/lib/modules/$KERNEL_VER/vmlinuz" \
    --initrd "/tmp/initramfs-${KERNEL_VER}.img" \
    --cmdline "@/etc/kernel/cmdline" \
    --secureboot-private-key "/tmp/noamd.key" \
    --secureboot-certificate "/etc/pki/noamd/noamd.crt" \
    --output "/boot/EFI/Linux/cachyos-${KERNEL_VER}.efi"

# C. Sign the systemd-boot binary (The bootloader itself)
# This allows the MS Shim to load systemd-boot
if [ -f "/usr/lib/systemd/boot/efi/systemd-bootx64.efi" ]; then
    sbsign --key "/tmp/noamd.key" \
           --cert "/etc/pki/noamd/noamd.crt" \
           "/usr/lib/systemd/boot/efi/systemd-bootx64.efi" \
           --output "/boot/systemd-bootx64.efi"
fi

# Clean up temp initramfs to save space
rm -f "/tmp/initramfs-${KERNEL_VER}.img"

### 4. SERVICES (The "Preset" Method)
# This replaces your loop. It is safer and cleaner for Immutable OS.
mkdir -p /usr/lib/systemd/system-preset
cat <<EOF > /usr/lib/systemd/system-preset/50-noamd.preset
enable gdm.service
enable ananicy-cpp.service
enable iwd.service
enable NetworkManager.service
enable systemd-resolved.service
enable uksmd.service
enable podman.socket
EOF

# Set default target
systemctl set-default graphical.target

# SELinux Tweaks
setsebool -P domain_kernel_load_modules on

# DNS Fix
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

### 5. BOOTLOADER INSTALL
# We do NOT run 'kernel-install add' here because we did it manually above.
# We just ensure depmod is clean.
depmod -a -b / "$KERNEL_VER"
