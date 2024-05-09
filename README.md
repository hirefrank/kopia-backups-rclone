

# Kopia Backup Script with Rclone Mounts

This script is designed to mount [Rclone](https://rclone.org/) remote directories on a Linux system and then [Kopia](https://kopia.io/) for backups.

## How It Works

1. The script defines two arrays:
   - `RCLONE_REMOTES`: Contains the names of the Rclone remotes to be mounted.
   - `MOUNT_POINTS`: Contains the local directories where the Rclone remotes will be mounted.
2. The script defines three functions:
   - `is_mounted()`: Checks if a given mount point is already mounted.
   - `mount_rclone()`: Mounts an Rclone remote to a given mount point.
3. The script loops through the `RCLONE_REMOTES` and `MOUNT_POINTS` arrays, checking if each mount point is already mounted. If not, it calls the `mount_rclone()` function to mount the corresponding Rclone remote.
4. If any directories are successfully mounted, the script prints a list of the mounted directories.
5. The script then performs a Kopia snapshot backup of the user's home directory.

## Usage

1. Make sure you have Rclone and Kopia installed on your system.
2. Update the `RCLONE_REMOTES` and `MOUNT_POINTS` arrays with the appropriate values for your setup.
3. Run the script using the following command:

   ```bash
   ./backup.sh
   ```

   This will mount the Rclone remotes and perform a Kopia backup of the home directory.

4. To unmount the Rclone remotes, you can run the script again, and it will automatically unmount any directories that were previously mounted.

## Notes

- The script assumes that the Rclone remotes are configured and accessible on the system.
- The script appends the path `:media/by-month` to the Google Photos mount point to access the media files.
- The script performs a Kopia snapshot backup of the home directory as an example. You can modify this part of the script to perform any additional operations on the mounted directories.

## Scheduling

Easily create a daily cron:
```
0 11 * * * /home/frank/Projects/kopia-backups-rclone/backup.sh >> /home/frank/backup.log 2>&1
```

Create a weekly cron to sync the kopia repository to another drive/location:
```
0 14 * * 1 kopia repository sync-to filesystem --path /mnt/external/backup/ >> /home/frank/sync.log 2>&1
```

## Todos
Notes mostly for me.
- ngdrive
- nphotos
- ndropbox
