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

## Configuring snapper 

