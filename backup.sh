#!/bin/bash

# Define arrays for rclone remotes and mount points
declare -a RCLONE_REMOTES=("fcharris-gdrive" "fcharris-gphotos" "fcharris-dropbox")
declare -a MOUNT_POINTS=("/home/frank/gdrive" "/home/frank/gphotos" "/home/frank/dropbox")
declare -a MOUNTED_DIRS=()  # Array to store successfully mounted directories

# Function to check if rclone directory is mounted
is_mounted() {
    local mount_point=$1
    if grep -qs "$mount_point" /proc/mounts; then
        echo "rclone directory $mount_point is already mounted."
        return 0
    elif pgrep -f "rclone.*$mount_point" > /dev/null; then
        echo "rclone process for $mount_point is running, assuming it's mounted."
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
    rclone mount "$rclone_remote": "$mount_point" \
        --allow-other \
        --vfs-cache-mode writes \
        --vfs-cache-poll-interval 0 \
        --volname "$rclone_remote" \
        > "/tmp/rclone_mount_$rclone_remote.log" 2>&1 &
    
    local rclone_pid=$!
    sleep 5  # Give it some time to mount

    if kill -0 $rclone_pid 2>/dev/null; then
        if grep -qs "$mount_point" /proc/mounts || ls "$mount_point" &>/dev/null; then
            echo "rclone directory $mount_point mounted successfully."
            MOUNTED_DIRS+=("$mount_point")
        else
            echo "Mount process is running for $mount_point, but the mount point doesn't seem to be working."
        fi
    else
        echo "Failed to mount rclone directory $mount_point. Check /tmp/rclone_mount_$rclone_remote.log for errors."
    fi
}

unmount_rclone() {
    local mount_point=$1
    echo "Unmounting rclone directory $mount_point..."
    fusermount -u "$mount_point"
    if [ $? -eq 0 ]; then
        echo "rclone directory $mount_point unmounted successfully."
    else
        echo "Failed to unmount rclone directory $mount_point."
    fi
}

# Loop through the rclone remotes and mount points
for i in "${!RCLONE_REMOTES[@]}"; do
    rclone_remote="${RCLONE_REMOTES[$i]}"
    mount_point="${MOUNT_POINTS[$i]}"
    
    if ! is_mounted "$mount_point"; then
        # Attempt to unmount, just in case there's a stale mount
        fusermount -uz "$mount_point" 2>/dev/null
        mount_rclone "$rclone_remote" "$mount_point"
    else
        echo "Skipping mount for $mount_point as it's already mounted."
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

# Backup home directory
kopia snapshot create ~/

# Unmount all mounted directories
for mounted_dir in "${MOUNTED_DIRS[@]}"; do
    unmount_rclone "$mounted_dir"
done
