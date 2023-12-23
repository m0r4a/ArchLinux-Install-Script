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

select microcode_option in "amd-ucode" "intel-ucode" "None"; do
    case $microcode_option in
        "amd-ucode")
            microcode_package="amd-ucode"
            break
            ;;
        "intel-ucode")
            microcode_package="intel-ucode"
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

# Executing the command
pacstrap /mnt base linux linux-firmware vim $microcode_package\

# Generating the fstab 
genfstab -U /mnt >> /mnt/etc/fstab 

# Getting into the install
arch-chroot /mnt

# Creating the zoneinfo
read -p "¿Do you know your zoneinfo? (S/N): " know_timezone

case $know_timezone in
    [SsYy]) 
        # If the user knows the ZoneInfo, ask for it
        read -p "Write your zoneinfo (e.g 'America/Mexico_City'): " timezone
        ;;
    *)
        # If the user doesnt know its zoneinfo, they're shown
        echo "Using timedatectl to show the available timezones"
        sleep 3
        timedatectl list-timezones
        echo
        read -p "Ingresa tu zona horaria: " timezone
        ;;
esac

# Creating the symlink 
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime

# Synchronizing the system and the hardware clock 
hwclock --systohc

# Deleting the coment on the en_US.UTF-8
sed -i '171s/^.//' /etc/locale.gen

# Generating the locale 
echo "Generating the locale.."
locale-gen

# Sending the info to the locale.conf
echo "LANG=en_US.UTF-8" > locale.conf

# Configuring the hostname
read -p "Enter the hostname of your computer: " hostnme
echo "$hostnme" > /etc/hostname

# Configuring the hosts file (this can be simpler but i wanted to make the code easier to read)
echo "Configuring the /etc/hosts file"
echo "" >> /etc/hosts
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1    localhost" >> /etc/hosts
echo "127.0.1.1    $hostnme.localdomain    $hostnme" >> /etc/hosts

# Cleaning the screen
clear

# Creating a password for the root user
echo "This will be the password for the root user"
passwd

# Cleaning the screen
clear

# Installing the rest of the packages 
pacman -S grub efibootmgr networkmanager network-manager-applet wpa_supplicant mtools dosfstools git snapper bluez bluez-utils xdg-utils alsa-utils pulseaudio pulseaudio-bluetooth base-devel linux-headers 

