#!/bin/bash

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to check if command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        log "SUCCESS: $1"
    else
        log "ERROR: $1"
        exit 1
    fi
}

# Function to get user confirmation
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Operation cancelled by user"
        exit 1
    fi
}

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
    log "This script must be run as root"
    exit 1
fi

# Show available disks
log "Available disks:"
lsblk
echo

# Get disk device from user
read -p "Enter the device name for external storage (e.g., sda1): " DISK_DEVICE
if [ ! -b "/dev/$DISK_DEVICE" ]; then
    log "Device /dev/$DISK_DEVICE does not exist!"
    exit 1
fi

# Confirm formatting
confirm "WARNING: This will format /dev/$DISK_DEVICE. All data will be lost! Continue?"

# Format disk
log "Formatting /dev/$DISK_DEVICE..."
mkfs.ext4 "/dev/$DISK_DEVICE"
check_status "Format disk"

# Create mount point
log "Creating mount point..."
mkdir -p /media/NEXTCLOUD
check_status "Create mount point"

# Mount drive
log "Mounting drive..."
mount "/dev/$DISK_DEVICE" /media/NEXTCLOUD
check_status "Mount drive"

# Get UUID and set up fstab
UUID=$(blkid -s UUID -o value "/dev/$DISK_DEVICE")
if grep -q "$UUID" /etc/fstab; then
    log "fstab entry already exists"
else
    echo "UUID=$UUID /media/NEXTCLOUD ext4 defaults 0 2" >> /etc/fstab
    check_status "Add fstab entry"
fi

# Create directory structure
log "Creating Nextcloud directory structure..."
mkdir -p /media/NEXTCLOUD/nextcloud_data/admin/files
echo "# Nextcloud data directory" | sudo -u www-data tee /media/NEXTCLOUD/nextcloud_data/.ncdata
check_status "Create directory structure"

# Set permissions
log "Setting permissions..."
chown -R www-data:www-data /media/NEXTCLOUD/nextcloud_data
chmod -R 770 /media/NEXTCLOUD/nextcloud_data
check_status "Set permissions"

# Configure Nextcloud
log "Configuring Nextcloud..."
sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on
sudo -u www-data php /var/www/nextcloud/occ config:system:set datadirectory --value=/media/NEXTCLOUD/nextcloud_data
sudo -u www-data php /var/www/nextcloud/occ files:cleanup
sudo -u www-data php /var/www/nextcloud/occ cache:clear
sudo -u www-data php /var/www/nextcloud/occ files:scan --all
sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
check_status "Configure Nextcloud"

# Verify setup
log "Verifying setup..."
sudo -u www-data php /var/www/nextcloud/occ config:system:get datadirectory
sudo -u www-data php /var/www/nextcloud/occ files:scan --all

log "Setup complete! Please verify everything is working correctly."
