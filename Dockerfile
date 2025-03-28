FROM alpine:3.21.3 AS builder

# Install build dependencies
RUN apk add --no-cache bash build-base cmake coreutils linux-headers perl tree upx wget 

# Copy and run build script
COPY build-nginx-static.sh /
RUN /build-nginx-static.sh

# Create the final scratch image
FROM scratch

# Copy the built nginx and dirs from builder image, scratch can't mkdir
COPY --from=builder /nginx /nginx
COPY --from=builder /etc/passwd /etc/group /etc/
COPY --from=builder /var/www /var/www

# Expose ports
EXPOSE 80 443

# Set entrypoint
ENTRYPOINT ["/nginx/sbin/nginx", "-g", "daemon off;"]