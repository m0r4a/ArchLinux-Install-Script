read -p "Have you already created the partitions? (Y/N): " partitions_created

case $partitions_created in
    [Yy]) 
        # If the user has created partitions, continue with the script
        clear
        ;;
    *)
        # If the user hasn't created partitions, show the message and exit
        echo "Debes crear tus particiones antes de ejecutar el script."
        exit 1
        ;;
esac

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
pacstrap /mnt base linux linux-firmware vim $microcode_package\

# Generating the fstab 
genfstab -U /mnt >> /mnt/etc/fstab 

#################################################################################################################
# Apparently the arch-chroot doesn't work (or I am way to dumb) so i will collect the variables before hand #####

    # Creating the zoneinfo
read -p "¿Do you know your zoneinfo? (Y/N): " know_timezone

case $know_timezone in
    [Yy]) 
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

    # Asking for the hostname
read -p "Enter the hostname of your computer: " hostnme

    # Asking for the root password

while true; do
    # Prompt for the password
    read -s -p "Enter the ROOT password: " passwd1
    echo

    # Prompt for the password again for confirmation
    read -s -p "Enter your password again: " passwd2
    echo

    # Check if the passwords match
    if [ "$passwd1" == "$passwd2" ]; then
        # Passwords match, assign to the variable and exit the loop
        root_passwd="$passwd1"
        break
    else
        # Passwords don't match, display error message
        echo "Passwords do not match. Please try again."
    fi
done

 # Asking for the USER credentials

while true; do
    # Prompt for the password
    read -s -p "Enter the ROOT password: " passwd1
    echo

    # Prompt for the password again for confirmation
    read -s -p "Enter your password again: " passwd2
    echo

    # Check if the passwords match
    if [ "$passwd1" == "$passwd2" ]; then
        # Passwords match, assign to the variable and exit the loop
        user_passwd="$passwd1"
        break
    else
        # Passwords don't match, display error message
        echo "Passwords do not match. Please try again."
    fi
done

read -p "Plase, enter the username you want: " usernme

###############################################################################################################

# Getting into the install
arch-chroot /mnt /bin/bash <<EOF


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
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Configuring the hostname
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

# Including the btrfs module into the kernel
sed -i '7s/.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf
mkinitcpio -p linux

# Installing grub 
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enabling system services
systemctl enable NetworkManager
systemctl enable bluetooth

# Cleaning the screen
clear

# Setting root's password
echo "root:$root_passwd" | chpasswd

# Creating the user 
useradd -m $usernme
echo "$usernme:$user_passwd" | chpasswd
usermod -aG wheel,audio,video,storage $usernme
echo -e 'Now you will have to uncomment the line "%wheel ALL=(ALL:ALL) ALL" using Vim'
read -p "Press Enter to continue"
visudo

# Exiting the chroot
EOF

#umount -a
#echo "Install has been completed, you might want to reboot now"
#exit 0



