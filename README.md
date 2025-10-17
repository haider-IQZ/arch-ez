# arch-ez

**Personal Arch Linux installer script - Use at your own risk!**

This is my personal automated Arch Linux installer. It's configured for my specific setup and preferences. **This might not work for you** - it's designed for my workflow.

## ⚠️ Warning

- This script will **ERASE ALL DATA** on the selected disk
- It's configured with **my personal preferences** (timezone, locale, etc.)
- **Not guaranteed to work** on all systems
- Use at your own risk!

## What It Does

- **Auto-partitioning:** 512MB EFI + 4GB SWAP + rest for ROOT
- **Filesystem:** Choice of ext4 or btrfs
- **Kernel:** linux-rt (real-time kernel for gaming)
- **Bootloader:** GRUB (UEFI)
- **Audio:** Pipewire
- **Network:** NetworkManager
- **GPU:** NVIDIA drivers (nvidia-open-dkms) pre-installed
- **Timezone:** Asia/Baghdad (hardcoded)
- **Locale:** en_US.UTF-8 (hardcoded)

## Requirements

- UEFI system (no BIOS support)
- Internet connection
- Booted from Arch Linux ISO

## Usage

**Boot Arch ISO, then:**

```bash
# Get the script
curl -O https://raw.githubusercontent.com/haider-IQZ/arch-ez/main/install.sh

# Run it
sudo bash install.sh
```

**The script will ask for:**
1. Username
2. Password
3. Hostname (machine name)
4. Disk to install on
5. Filesystem (ext4 or btrfs)

Then it installs everything automatically.

## What Gets Installed

**Base System:**
- base, base-devel
- linux-rt, linux-rt-headers
- linux-firmware
- grub, efibootmgr
- vim
- networkmanager

**Audio:**
- pipewire, pipewire-pulse

**NVIDIA:**
- nvidia-open-dkms
- nvidia-utils
- nvidia-settings

## After Installation

The system will be ready to boot. You'll need to install a desktop environment or window manager separately (Hyprland, KDE, GNOME, etc.).

For NVIDIA optimization, check out my other repo:
https://github.com/haider-IQZ/Arch-Nvidia-Optimization

## Why This Exists

I got tired of doing manual Arch installs 130 times for testing. This automates my exact setup.

## License

Do whatever you want with it. No warranty, no support, no guarantees.

---

**Again: This is a personal script. It might break your system. You've been warned!** 🚀
