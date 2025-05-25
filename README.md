# micro-nginx
a very tiny nginx container


### building
`docker buildx build --builder nginx-builder --platform linux/amd64 --progress plain .`


```
docker buildx create \
  --name rosetta-nginx-builder \
  --driver docker-container \
  --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=104857600,env.BUILDKIT_STEP_LOG_MAX_SPEED=104857600
```
