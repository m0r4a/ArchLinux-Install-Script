echo "You have to create your partitions before running the script"

# Showing your partitions
lsblk 

# Gathering the partitions info
read -p "Select your boot partition, e.g /dev/sda1: " boot_p
read -p "Select your swap partition: " swap_p
read -p "Select the root partition: " root_p

# Checking the vars 
if [ -z "$boot_p" ] || [ -z "$swap_p" ] || [ -z "$root_p" ]; then
    echo "Error: You have to write all the partitions."
    exit 1
fi

# Cleaning the screen
clear

# Configuring the NTP
timedatectl set-ntp true

# Formatting boot partition
echo "Formatting the boot partition ($boot_p)..."
mkfs.fat -F32 $boot_p

# Creating the swap parittion and activating it
echo "Creating swap on partition ($swap_p)..."
mkswap $swap_p
swapon $swap_p

# Formatting root partition
echo "Formatting the root partition ($root_p)..."
mkfs.btrfs $root_p

# Mounting the root partition 
mount $root_p /mnt 

# Creating the subvolumes
echo 'Creating the subvolumes "root, home, .snapshots and var_log"..' 
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log

# Unmounting /mnt directory
umount /mnt

# Remounting 
mount -o noatime,compress=lzo,space_cache=v2,subvol=@ $root_p /mnt

  # Creating the directories
mkdir -p /mnt/{boot,home,.snapshots,var_log}

mount -o noatime,compress=lzo,space_cache=v2,subvol=@home $root_p /mnt/home
mount -o noatime,compress=lzo,space_cache=v2,subvol=@snapshots $root_p /mnt/.snapshots
mount -o noatime,compress=lzo,space_cache=v2,subvol=@var_log $root_p /mnt/var_log
