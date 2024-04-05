#!/bin/bash

# setup two crons
# 1. cron daily
# 0 11 * * * /home/frank/Projects/kopia-backups-rclone-mounts/backup.sh.sh >> /home/frank/backup.log 2>&1 &
# 2. cron weekly
# 0 14 * * 1 rsync -a /home/frank/backup/cloud /home/frank/external/backup >> /home/frank/rsync.log 2>&1 &

# todo
# ngdrive, nphotos, ndropbox

# Define arrays for rclone remotes and mount points
declare -a RCLONE_REMOTES=("fcharris-gdrive" "fcharris-gphotos")
declare -a MOUNT_POINTS=("/home/frank/gdrive" "/home/frank/gphotos")
declare -a MOUNTED_DIRS=()  # Array to store successfully mounted directories

# Function to check if rclone directory is mounted
is_mounted() {
    local mount_point=$1
    if mountpoint -q "$mount_point"; then
        echo "rclone directory $mount_point is already mounted."
        return 0
    else
        echo "rclone directory $mount_point is not mounted."
        return 1
    fi
}

# Function to mount rclone directory
mount_rclone() {
    local rclone_remote=$1
    local mount_point=$2
    echo "Mounting rclone directory $mount_point..."
    rclone mount "$rclone_remote": "$mount_point" --allow-other --vfs-cache-mode writes --daemon &>/dev/null &
    if [ $? -eq 0 ]; then
        echo "rclone directory $mount_point mounted successfully."
        MOUNTED_DIRS+=("$mount_point")  # Add successfully mounted directory to the array
    else
        echo "Failed to mount rclone directory $mount_point."
    fi
}

# Function to unmount rclone directory
unmount_rclone() {
    local mount_point=$1
    echo "Unmounting rclone directory $mount_point..."
    if mountpoint -q "$mount_point"; then
        fusermount -u "$mount_point"
        if [ $? -eq 0 ]; then
            echo "rclone directory $mount_point unmounted successfully."
        else
            echo "Failed to unmount rclone directory $mount_point."
        fi
    else
        echo "rclone directory $mount_point is not mounted."
    fi
}

# Loop through the rclone remotes and mount points
for i in "${!RCLONE_REMOTES[@]}"; do
    rclone_remote="${RCLONE_REMOTES[$i]}"
    mount_point="${MOUNT_POINTS[$i]}"

    # Check if rclone directory is mounted
    is_mounted "$mount_point"

    # Mount rclone directory if it's not mounted
    if [ $? -eq 1 ]; then
        mount_rclone "$rclone_remote" "$mount_point"
    fi
done

# Iterate over the successfully mounted directories
if [ "${#MOUNTED_DIRS[@]}" -gt 0 ]; then
    echo "Successfully mounted directories:"
    for mounted_dir in "${MOUNTED_DIRS[@]}"; do
        if [[ "$mounted_dir" == *"-gphotos" ]]; then
            dir_with_path="$mounted_dir:media/by-month"
            echo "$dir_with_path"
            # Perform any additional operations on the mounted directory with the appended path here
            # For example:
            kopia snapshot create "$dir_with_path"
        else
            echo "$mounted_dir"
            # Perform any additional operations on the mounted directory here
            # For example:
            kopia snapshot create "$mounted_dir/"
        fi
    done
else
    echo "No directories were successfully mounted."
fi

# backup home directory
kopia snapshot create ~/
