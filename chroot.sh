## This is the file you should run after arch-chasdfroot /mnt 

read -p "¿Do you know your zoneinfo? (Y/N): " know_timezone

case $know_timezone in
    [Yy]) 
        # If the user knows the ZoneInfo, ask for it
        read -p "Write your zoneinfo (e.g 'America/Mexico_City'): " timezone
        ;;
    *)
        # If the user doesnt know its zoneinfo, they're shown
        # This doesnt work idk why, should fix it someday xd
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
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Configuring the hostname
read -p "Enter the hostname of your computer: " hostnme
echo "$hostnme" > /etc/hostname

# Configuring the hosts file (this can be simpler but i wanted to make the code easier to read)
echo "Configuring the /etc/hosts file"
cat <<EOL >> /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    $hostnme.localdomain    $hostnme
EOL

# Cleaning the screen
clear

# Creating a password for the root user
echo "This will be the password for the root user"
passwd

# Cleaning the screen
clear

# Installing the rest of the packages 
pacman -S grub efibootmgr networkmanager network-manager-applet wpa_supplicant mtools dosfstools git snapper bluez bluez-utils xdg-utils alsa-utils pulseaudio pulseaudio-bluetooth base-devel linux-headers rsync 

# Including the btrfs module into the kernel
sed -i '7s/.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf

# Re-generating the config
mkinitcpio -p linux

# Installing grub 
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enabling system services
systemctl enable NetworkManager
systemctl enable bluetooth

# Cleaning the screen
clear

# Creating the user 
read -p "Enter the username you want: " usernme
useradd -m $usernme
echo "Now enter the password for your user"
passwd $usernme
usermod -aG wheel,audio,video,storage $usernme

# Cleaning the screen
clear

# Configuring the sudoers file
chmod u+w /etc/sudoers
sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^#//' /etc/sudoers
chmod u-w /etc/sudoers

echo "Install completed, now you might want to exit, do umount -a and reboot"
exit 0


