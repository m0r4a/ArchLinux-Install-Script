## Checking if running as sudo
if [ $(echo $USER) == 'root' ]; then
	echo "Do NOT run this script as root"
 	echo "exiting..."
 	exit 1
fi

## Installing yay
echo "Installing yay..."
cd /opt
sudo git clone https://aur.archlinux.org/yay-git.git
USERBK=$USER
sudo chown -R $USERBK:$USERBK ./yay-git
cd yay-git
makepkg -si

# Configuring snapper

## Downloading necessary stuff
yay -S grub-btrfs snap-pac-grub snap-pac snapper-rollback 

## Logging into sudo 
sudo su

## Unmounting and removing the .snapshots subvol
umount /.snapshots
rm -rf /.snapshots

## Creating the configuration
snapper -c root create-config /  

## Configuring snapper timeline

### Adding your username 
sed -i "s/ALLOW_USERS=\"\"/ALLOW_USERS=\"$USERBK\"/" /etc/snapper/configs/root

### Recommended cleanup on the arch wiki
sed -i 's/TIMELINE_LIMIT_HOURLY="[0-9]\+"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_DAILY="[0-9]\+"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_WEEKLY="[0-9]\+"/TIMELINE_LIMIT_WEEKLY="0"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_MONTHLY="[0-9]\+"/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
sed -i 's/TIMELINE_LIMIT_YEARLY="[0-9]\+"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

### This (i think) is not on the arch wiki but I find 50 snapshots excessive
sed -E -i 's/NUMBER_LIMIT="[0-9]+"/NUMBER_LIMIT="25"/' /etc/snapper/configs/root

### Setting a different subvol default
btrfs subvol set-default 256 /

### Enable the timeline
systemctl enable --now grub-btrfsd
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer

## Clean the terminal
clear

## I truly dont know how this works, i've got this code from https://github.com/Antynea/grub-btrfs/issues/92

#################################################################################
tmpfile1=$(mktemp)
cat << 'EOF' > "$tmpfile1"
#!/usr/bin/ash

run_hook() {
	local current_dev=$(resolve_device "$root"); # resolve devices for blkid
	if [[ $(blkid ${current_dev} -s TYPE -o value) = "btrfs" ]]; then
		current_snap=$(mktemp -d); # create a random mountpoint in root of initrafms
		mount -t btrfs -o ro,"${rootflags}" "$current_dev" "${current_snap}";
		if [[ $(btrfs property get "${current_snap}" ro) != "ro=false" ]]; then # check if the snapshot is in read-only mode
			snaproot=$(mktemp -d);
			mount -t btrfs -o rw,subvolid=5 "${current_dev}" "${snaproot}";
			rwdir=$(mktemp -d)
			mkdir -p ${snaproot}${rwdir} # create a random folder in root fs of btrfs device
			btrfs sub snap "${current_snap}" "${snaproot}${rwdir}/rw";
			umount "${current_snap}";
			umount "${snaproot}"
			rmdir "${current_snap}";
			rmdir "${snaproot}";
			rootflags=",subvol=${rwdir}/rw";
		else
			umount "${current_snap}";
			rmdir "${current_snap}";
		fi
	fi
}
EOF

sudo tee /etc/initcpio/hooks/switchsnaprotorw < "$tmpfile1" >/dev/null
rm "$tmpfile1"

tmpfile2=$(mktemp)
cat << 'EOF' > "$tmpfile2"
#!/bin/bash

build() {
    add_module btrfs
    add_binary btrfs
    add_binary btrfsck
    add_binary blkid
    add_runscript
}

help() {
    cat <<HELPEOF
This hook creates a copy of the snapshot in read-only mode before boot.
HELPEOF
}
EOF

tee /etc/initcpio/install/switchsnaprotorw < "$tmpfile2" >/dev/null
rm "$tmpfile2"
#################################################################################

# Adding the hook to the config file
sed -i 's/\(HOOKS=(.*\))/\1 switchsnaprotorw)/' /etc/mkinitcpio.conf

## Regenerating the config 
mkinitcpio -P

## Configuring snapper-rollback
sed -i 's/@snapshots/@.snapshots/' /etc/snapper-rollback.conf

# Getting the root partition
p_root=$(awk '/\s\/\s/ {print prev} {prev = $0}' /etc/fstab | sed 's/^#\s*//')

# Adding the root partition to the snapper-rollback config file
sed -i '/^#dev/d' /etc/snapper-rollback.conf
echo "dev = $p_root" | sudo tee -a /etc/snapper-rollback.conf

# Finishing sudo´s process 
su $USERBK

## Adding grub resolution
echo "Please, select the GRUB's resolution"

select res_option in "1920x1200" "1920x1080"; do
    case $res_option in
        "1920x1200")
            resolution="1920x1200"
            break
            ;;
        "1920x1080")
            resolution="1920x1080"
            break
            ;;
        *)
            echo "Please, select a valid option"
            ;;
    esac
done

sudo sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/s/\"\(.*\)\"/\"loglevel=3 quiet video=$resolution\"/" /etc/default/grub

## Recreating grub's config

sudo grub-mkconfig -o /boot/grub/grub.cfg
