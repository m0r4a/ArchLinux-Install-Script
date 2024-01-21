## Installing yay
echo "Installing yay..."
cd /opt
sudo git clone https://aur.archlinux.org/yay-git.git
USERBK=$USER
sudo chown -R $USERBK:$USERBK ./yay-git
cd yay-git
makepkg -si

# Configuring snapper

## Preparing the backup rollback
yay -S grub-btrfs snap-pac-grub snap-pac snapper-rollback 

## Unmounting and removing the .snapshots subvol
sudo umount /.snapshots
sudo rm -rf /.snapshots

## Creating the configuration
sudo snapper -c root create-config /  

## Configuring snapper timeline

### Adding your username 
sudo sed -i "s/ALLOW_USERS=\"\"/ALLOW_USERS=\"$USER\"/" /etc/snapper/configs/root

### Recommended cleanup on the arch wiki
sudo sed -i 's/TIMELINE_LIMIT_HOURLY="[0-9]\+"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_DAILY="[0-9]\+"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_WEEKLY="[0-9]\+"/TIMELINE_LIMIT_WEEKLY="0"/' /etc/snapper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_MONTHLY="[0-9]\+"/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_YEARLY="[0-9]\+"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

### Setting a different subvol default
sudo btrfs subvol set-default 256 /

### Enable the timeline
sudo systemctl enable --now grub-btrfsd
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

## Clean the terminal
clean 

## I truly dont know how this works, i've got this code from https://github.com/Antynea/grub-btrfs/issues/92

cat << 'EOF' > /etc/initcpio/hooks/switchsnaprotorw
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

# Same here
cat << 'EOF' > /etc/initcpio/install/switchsnaprotorw
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

# Adding the hook to the config file
sed -i 's/\(HOOKS=(.*\))/\1 switchsnaprotorw)/' /etc/mkinitcpio.conf

## Regenerating the config 
sudo mkinitcpio -P

## Configuring snapper-rollback
sudo sed -i 's/@snapshots/@.snapshots/' /etc/snapper-rollback.conf

## Getting the root partition 
p_root=$(awk '/\s\/\s/ {print prev} {prev = $0}' /etc/fstab | sed 's/^#\s*//')
sudo echo "dev = $p_root"

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
