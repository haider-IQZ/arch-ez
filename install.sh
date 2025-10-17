#!/bin/bash
# Fast Arch Linux Installer
# Automated installation with minimal prompts

set -e

echo "======================================"
echo "Fast Arch Linux Installer"
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root!"
    echo "Run: sudo bash arch-install.sh"
    exit 1
fi

# Check if running in UEFI mode
if [ ! -d /sys/firmware/efi ]; then
    echo "ERROR: This script only supports UEFI systems!"
    exit 1
fi

echo "======================================"
echo "System Configuration"
echo "======================================"
echo ""

# Get username
read -p "Enter username for your account: " USERNAME
while [ -z "$USERNAME" ]; do
    echo "Username cannot be empty!"
    read -p "Enter username for your account: " USERNAME
done

# Get password
while true; do
    read -sp "Enter password for $USERNAME: " PASSWORD
    echo ""
    read -sp "Confirm password: " PASSWORD2
    echo ""
    if [ "$PASSWORD" = "$PASSWORD2" ]; then
        break
    else
        echo "Passwords don't match! Try again."
    fi
done

# Get hostname (machine name)
read -p "Enter hostname (machine name): " HOSTNAME
while [ -z "$HOSTNAME" ]; do
    echo "Hostname cannot be empty!"
    read -p "Enter hostname (machine name): " HOSTNAME
done

echo ""
echo "Configuration:"
echo "  Username: $USERNAME"
echo "  Hostname: $HOSTNAME"
echo ""

echo "======================================"
echo "Disk Selection"
echo "======================================"
echo ""
echo "WARNING: This will ERASE ALL DATA on the selected disk!"
echo ""

# List available disks
echo "Available disks:"
lsblk -d -n -o NAME,SIZE,TYPE | grep disk | nl
echo ""

# Select disk
read -p "Enter disk number to install on (e.g., 1 for first disk): " disk_num
DISK=$(lsblk -d -n -o NAME,TYPE | grep disk | sed -n "${disk_num}p" | awk '{print $1}')

if [ -z "$DISK" ]; then
    echo "ERROR: Invalid disk selection!"
    exit 1
fi

DISK="/dev/$DISK"
echo "Selected disk: $DISK"
echo ""

# Choose filesystem
echo "Choose filesystem:"
echo "1) ext4 (stable, fast)"
echo "2) btrfs (snapshots, compression)"
read -p "Enter choice (1-2): " fs_choice

case $fs_choice in
    1)
        FILESYSTEM="ext4"
        ;;
    2)
        FILESYSTEM="btrfs"
        ;;
    *)
        echo "Invalid choice, using ext4"
        FILESYSTEM="ext4"
        ;;
esac

echo "Using filesystem: $FILESYSTEM"
echo ""

# Final confirmation
read -p "This will ERASE $DISK and install Arch Linux. Continue? (yes/NO): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "======================================"
echo "Step 1: Partitioning Disk"
echo "======================================"
echo ""

# Unmount if mounted
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

# Wipe disk
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"

# Create partitions
echo "Creating partitions..."
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK"      # EFI partition (512MB)
sgdisk -n 2:0:+4G -t 2:8200 -c 2:"SWAP" "$DISK"       # SWAP partition (4GB)
sgdisk -n 3:0:0 -t 3:8300 -c 3:"ROOT" "$DISK"         # ROOT partition (rest)

# Reload partition table
partprobe "$DISK"
sleep 2

# Set partition variables
if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
    EFI_PART="${DISK}p1"
    SWAP_PART="${DISK}p2"
    ROOT_PART="${DISK}p3"
else
    EFI_PART="${DISK}1"
    SWAP_PART="${DISK}2"
    ROOT_PART="${DISK}3"
fi

echo "Partitions created:"
echo "  EFI:  $EFI_PART (512MB)"
echo "  SWAP: $SWAP_PART (4GB)"
echo "  ROOT: $ROOT_PART (remaining)"
echo ""

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkswap "$SWAP_PART"

if [ "$FILESYSTEM" = "btrfs" ]; then
    mkfs.btrfs -f "$ROOT_PART"
else
    mkfs.ext4 -F "$ROOT_PART"
fi

echo "✓ Partitions formatted"
echo ""

# Mount partitions
echo "Mounting partitions..."
mount "$ROOT_PART" /mnt

# Create EFI mount point
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

# Enable swap
swapon "$SWAP_PART"

echo "✓ Partitions mounted:"
echo "  $ROOT_PART -> /mnt"
echo "  $EFI_PART -> /mnt/boot/efi"
echo "  $SWAP_PART -> swap enabled"
echo ""

lsblk "$DISK"
echo ""

echo "======================================"
echo "Disk partitioning complete!"
echo "======================================"
echo ""

echo "======================================"
echo "Step 2: Installing Base System"
echo "======================================"
echo ""

# Update pacman mirrors for faster downloads
echo "Updating mirror list..."
reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || echo "reflector not available, using default mirrors"

# Install base system with all essential packages
echo "Installing base system (this will take a few minutes)..."
pacstrap -K /mnt \
    base \
    base-devel \
    linux-firmware \
    linux-rt \
    linux-rt-headers \
    grub \
    efibootmgr \
    vim \
    networkmanager \
    pipewire \
    pipewire-pulse \
    nvidia-open-dkms \
    nvidia-utils \
    nvidia-settings

echo "✓ Base system installed"
echo ""

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "✓ fstab generated"
echo ""

echo "======================================"
echo "Base system installation complete!"
echo "======================================"
echo ""

echo "======================================"
echo "Step 3: System Configuration"
echo "======================================"
echo ""

# Create chroot configuration script
cat > /mnt/root/configure.sh << 'CHROOT_EOF'
#!/bin/bash
set -e

echo "Setting timezone to Asia/Baghdad..."
ln -sf /usr/share/zoneinfo/Asia/Baghdad /etc/localtime
hwclock --systohc
echo "✓ Timezone set"

echo "Setting locale to en_US.UTF-8..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "✓ Locale set"

echo "Setting hostname..."
echo "HOSTNAME_PLACEHOLDER" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   HOSTNAME_PLACEHOLDER.localdomain HOSTNAME_PLACEHOLDER
EOF
echo "✓ Hostname set"

echo "Creating user USERNAME_PLACEHOLDER..."
useradd -m -G wheel,audio,video,storage -s /bin/bash USERNAME_PLACEHOLDER
echo "USERNAME_PLACEHOLDER:PASSWORD_PLACEHOLDER" | chpasswd
echo "✓ User created"

echo "Setting root password..."
echo "root:PASSWORD_PLACEHOLDER" | chpasswd
echo "✓ Root password set"

echo "Enabling sudo for wheel group..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "✓ Sudo enabled"

echo "Installing GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
echo "✓ GRUB installed"

echo "Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg
echo "✓ GRUB configured"

echo "Enabling NetworkManager..."
systemctl enable NetworkManager
echo "✓ NetworkManager enabled"

echo "Enabling pipewire..."
systemctl --user enable pipewire pipewire-pulse
echo "✓ Pipewire enabled"

echo "Configuration complete!"
CHROOT_EOF

# Replace placeholders with actual values
sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" /mnt/root/configure.sh
sed -i "s/USERNAME_PLACEHOLDER/$USERNAME/g" /mnt/root/configure.sh
sed -i "s/PASSWORD_PLACEHOLDER/$PASSWORD/g" /mnt/root/configure.sh

# Make script executable
chmod +x /mnt/root/configure.sh

# Run configuration in chroot
echo "Running system configuration..."
arch-chroot /mnt /root/configure.sh

# Clean up
rm /mnt/root/configure.sh

echo ""
echo "======================================"
echo "System configuration complete!"
echo "======================================"
echo ""
echo "Installation finished!"
echo ""
echo "System details:"
echo "  Username: $USERNAME"
echo "  Hostname: $HOSTNAME"
echo "  Timezone: Asia/Baghdad"
echo "  Locale: en_US.UTF-8"
echo ""
echo "You can now reboot into your new Arch Linux system!"
echo ""
read -p "Reboot now? (y/N): " reboot_choice
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    umount -R /mnt
    reboot
else
    echo "Remember to unmount /mnt and reboot manually:"
    echo "  umount -R /mnt"
    echo "  reboot"
fi
