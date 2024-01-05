read -p "Have you already created the partitions? (Y/N): " partitions_created

case $partitions_created in
    [Yy]) 
        # If the user has created partitions, continue with the script
        clear
        ;;
    *)
        # If the user hasn't created partitions, show the message and exit
        echo "You have to create the partitions before executing the script."
        exit 1
        ;;
esac

# Showing your partitions
lsblk 

# Asking for the partitions 
read -p "Select your boot partition, e.g: sda1: " boot_p
read -p "Select your swap partition: " swap_p
read -p "Select the root partition: " root_p

# Adding /dev/ to the partitions
boot_p="/dev/$boot_p"
swap_p="/dev/$swap_p"
root_p="/dev/$root_p"

# Check if the vars are not null
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
mkfs.btrfs -f $root_p

# Cleaning the screen
clear

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
echo "Creating the directories for the subvolumes..."
mkdir -p /mnt/{boot,home,.snapshots,var_log}

echo "Mounting the subvolumes..."
mount -o noatime,compress=lzo,space_cache=v2,subvol=@home $root_p /mnt/home
mount -o noatime,compress=lzo,space_cache=v2,subvol=@snapshots $root_p /mnt/.snapshots
mount -o noatime,compress=lzo,space_cache=v2,subvol=@var_log $root_p /mnt/var_log

  # Mounting boot
mount $boot_p /mnt/boot

# Cleaning the screen
clear

# Installing the base directories with the microcode picking

echo "Please, select which microcode you want to install"

select microcode_option in "intel-ucode" "amd-ucode" "None"; do
    case $microcode_option in
        "intel-ucode")
            microcode_package="intel-ucode"
            break
            ;;
        "amd-ucode")
            microcode_package="amd-ucode"
            break
            ;;
        "None")
            microcode_package=""
            break
            ;;
        *)
            echo "Please, select a valid option"
            ;;
    esac
done

# Cleaning the screen
clear

# Installing the basic packages for linux
echo -e "The packages: base linux linux-firmware vim $microcode_package will be installed \n"
read -p "Press Enter to continue"
pacstrap /mnt base linux linux-firmware vim $microcode_package

# Generating the fstab 
genfstab -U /mnt >> /mnt/etc/fstab 

# Cleaning the screen
clear 

# Moving the chroot code into the chroot directory 
cp /root/ArchLinux-Install-Script/chroot.sh /mnt

echo -e "Now please do:\n arch-chroot /mnt\nand run the chroot.sh script \n"
read -p "Press Enter to continue"

exit 0



