#!/usr/bin/env bash

# if you dont succeed, try try again

# stop colima running normally
echo "stopping colima"
colima stop default
colima stop rosetta

# ensure all are stopped
if o=$(colima ls | awk 'NR > 1 && $2 != "Stopped" { print "Error: Profile \047" $1 "\047 is not stopped (Status: " $2 ")."; found=1 } END { exit found }'); then
  :
else
  echo "$o" >&2 && exit 1
fi


# start colima with rosetta profile
echo "starting colima with rosetta emulation"
colima start rosetta

echo "building nginx"
docker buildx build \
  -t rhemz/micro-nginx:latest \
  --builder rosetta-nginx-builder \
  --platform linux/amd64 \
  --progress plain \
  --load .
