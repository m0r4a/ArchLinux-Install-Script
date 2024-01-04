# Configuring snapper

## Unmounting and removing the .snapshots subvol

sudo umount /.snapshots
sudo rm -r /.snapshots

## Creating the configuration

sudo snapper -c root create-config / 

## Deleting the subvolume created by the command

sudo btrfs subvolume delete /.snapshots 

## Recreating the .snapshots dir

sudo mkdir /.snapshots 

## Remounting 

sudo mount -a

## Editing the permissions of the folder

sudo chmod 750 /.snapshots

## Configuring snapper timeline

### Adding your username 
sudo sed -i "s/ALLOW_USERS=\"\"/ALLOW_USERS=\"$USER\"/" /etc/snapper/configs/root

### Recommended cleanup on the arch wiki
sudo sed -i 's/TIMELINE_LIMIT_HOURLY="[0-9]\+"/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_DAILY="[0-9]\+"/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_WEEKLY="[0-9]\+"/TIMELINE_LIMIT_WEEKLY="0"/' /etc/snapper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_MONTHLY="[0-9]\+"/TIMELINE_LIMIT_MONTHLY="0"/' /etc/snapper/configs/root
sudo sed -i 's/TIMELINE_LIMIT_YEARLY="[0-9]\+"/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root

### Enable the timeline
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

## Clean the terminal
clean 

## Pospuesto
echo "Installing yay..."
cd /opt
sudo git clone https://aur.archlinux.org/yay-git.git
sudo chown -R $USER:$USER ./yay-git
cd yay-git
makepkg -si
