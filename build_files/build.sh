#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1
#Cachy Kernels
curl -L https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos/repo/fedora-43/bieszczaders-kernel-cachyos-fedora-43.repo \
    -o /etc/yum.repos.d/kernel-cachyos.repo

# RPMfusion repos
dnf5 -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf config-manager setopt fedora-cisco-openh264.enabled=1

dnf config-manager setopt install_weak_deps=0

dnf remove -y --allow-erasing \
	       --disable-plugin=protected_packages \
	       kernel \
	       kernel-core \
	       kernel-modules \
	       wpa_supplicant \
	       sudo \
	       pulseaudio

# this installs a package from fedora repos
dnf install -y --setopt keepcache=1 \
		kakoune \
		fish \
		kernel-cachyos-lto\
		f2fs-tools\
		composefs-rs \
        	gdm \
        	gnome-shell \
        	flatpak \
        	ananicy-cpp \
        	mesa-dri-drivers \
        	systemd-boot \
        	xdg-desktop-portal-gnome \
        	xdg-user-dirs-gtk \
        	iwd \
        	systemd-resolved \
        	pipewire \
        	wireplumber \
        	NetworkManager-wifi \
        	plymouth 

systemctl enable podman.socket

systemctl enable gdm ananicy-cpp iwd NetworkManager systemd-resolved

systemctl set-default graphical.target

setsebool -P domain_kernel_load_modules on

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

mkdir -p /etc/NetworkManager/conf.d /etc/kernel /etc/dracut.conf.d

echo -e "[device]\nwifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf

echo 'add_dracutmodules+=" f2fs "' > /etc/dracut.conf.d/f2fs.conf

echo "composefs=1 rootfstype=f2fs rw preempt=full quiet rhgb" >> /etc/kernel/cmdline

kernel-install add-all


