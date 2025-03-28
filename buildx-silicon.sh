#!/usr/bin/env bash

# if you dont succeed, try try again

# stop colima running normally
echo "stopping colima"
colima stop

# start colima with rosetta 2 integration
echo "starting colima with rosetta emulation"
colima start --vz-rosetta --cpu 8

echo "building nginx"
BUILDKIT_STEP_LOG_MAX_SIZE=0 docker buildx build --platform linux/amd64 --progress plain .

# stop colima running in rosetta 2 mode and restart in default arm64 mode
echo "stopping colima with rosetta emulation"
colima stop
echo "starting colima normally"
colima start
