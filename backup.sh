#!/bin/bash

# Function to get rclone remotes from config file
get_rclone_remotes() {
    grep '^\[kopia-.*\]$' ~/.config/rclone/rclone.conf | sed 's/\[//;s/\]//'
}

# Define arrays for rclone remotes and mount points
mapfile -t RCLONE_REMOTES < <(get_rclone_remotes)
declare -a MOUNT_POINTS=()
for remote in "${RCLONE_REMOTES[@]}"; do
    MOUNT_POINTS+=("/tmp/$remote")
done
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
    mkdir -p "$mount_point"
    echo "Mounting rclone directory $mount_point..."
    rclone mount "$rclone_remote": "$mount_point" \
        --vfs-cache-mode writes \
        --vfs-cache-poll-interval 0 \
        --volname "$rclone_remote" \
        > "/tmp/rclone_mount_$rclone_remote.log" 2>&1 &

    local rclone_pid=$!
    trap "kill $rclone_pid; exit" SIGINT SIGTERM EXIT
    sleep 5  # Give it some time to mount
    if kill -0 $rclone_pid 2>/dev/null; then
        if grep -qs "$mount_point" /proc/mounts || ls "$mount_point" &>/dev/null; then
            echo "rclone directory $mount_point mounted successfully."
            MOUNTED_DIRS+=("$mount_point")  # Add mount point to the array
        else
            echo "Mount process is running for $mount_point, but the mount point doesn't seem to be working."
        fi
    else
        echo "Failed to mount rclone directory $mount_point. Check /tmp/rclone_mount_$rclone_remote.log for errors."
    fi
}

# Function to unmount rclone directory
unmount_rclone() {
    local mount_point=$1
    echo "Unmounting rclone directory $mount_point..."
    local rclone_pid=$(pgrep -f "rclone.*$mount_point")
    if [ -n "$rclone_pid" ]; then
        kill "$rclone_pid"
    fi
    fusermount -uz "$mount_point"
    if [ $? -eq 0 ]; then
        echo "rclone directory $mount_point unmounted successfully."
        rmdir "$mount_point"
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

# Verify mounted directories
echo "Successfully mounted directories:"
for dir in "${MOUNTED_DIRS[@]}"; do
    echo " - $dir"
done

# Create snapshots
if [ "${#MOUNTED_DIRS[@]}" -gt 0 ]; then
    for mounted_dir in "${MOUNTED_DIRS[@]}"; do
        echo "Creating snapshot for $mounted_dir..."
        if ! kopia snapshot create "$mounted_dir"/*; then
            echo "WARNING: Failed to create snapshot for $mounted_dir" >&2
        else
            echo "Snapshot created for $mounted_dir."
        fi
    done
else
    echo "No directories were successfully mounted."
fi

# Backup home directory
echo "Creating snapshot of home directory..."
if ! kopia snapshot create ~/; then
    echo "WARNING: Failed to create snapshot of home directory." >&2
else
    echo "Snapshot of home directory created successfully."
fi

# Unmount all mounted directories
echo "Unmounting directories..."
for mounted_dir in "${MOUNTED_DIRS[@]}"; do
    unmount_rclone "$mounted_dir"
done
echo "All directories unmounted."
echo "Backup process completed."
