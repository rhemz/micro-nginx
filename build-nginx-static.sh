#!/usr/bin/env bash
set -e

# Create build directory
mkdir -p /build
cd /build

# Versions.  Last updated Mar 2025
NGINX_VERSION="1.27.4"
OPENSSL_VERSION="3.4.1"
PCRE_VERSION="10.45"
ZLIB_VERSION="1.3.1"

echo "procs: $(nproc)"

# Download sources
echo "Downloading source files..."
wget --no-verbose https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
wget --no-verbose https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz
wget --no-verbose https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE_VERSION}/pcre2-${PCRE_VERSION}.tar.gz
wget --no-verbose https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz

echo "dir contents:"
ls -latrh
echo "done dir contents"

# Extract everything
echo "Extracting source files..."
find . -name "*.tar.gz" -exec tar -xzf {} \;

echo "dir contents:"
ls -latrh

# Build zlib statically
echo "\n\n\nBuilding zlib..."
cd zlib-${ZLIB_VERSION}
./configure --static
make -j$(nproc)
cd ..

# Build PCRE statically
echo "\n\n\nBuilding PCRE..."
cd pcre2-${PCRE_VERSION}
./configure \
  --disable-shared \
  --enable-static \
  --host=x86_64-linux-gnu \
  ac_cv_c_compiler_gnu=yes \
  ac_cv_prog_cc_g=yes \
  ac_cv_prog_cc_c_o=yes
make -j$(nproc)
cd ..

# Build OpenSSL statically
echo "\n\n\nBuilding OpenSSL..."
cd openssl-${OPENSSL_VERSION}
./Configure no-shared no-async linux-x86_64 --prefix=/build/openssl-build --openssldir=/build/openssl-build
./configdata.pm --help
make -j$(nproc)
# make test
cd ..

# Build Nginx with everything statically linked
echo "\n\n\nBuilding Nginx..."
cd nginx-${NGINX_VERSION}

./configure \
    --prefix=/nginx \
    --sbin-path=/nginx/sbin/nginx \
    --conf-path=/nginx/nginx.conf \
    --error-log-path=/dev/stderr \
    --http-log-path=/dev/stdout \
    --pid-path=/nginx/nginx.pid \
    --lock-path=/nginx/nginx.lock \
    --with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_gzip_static_module \
    --with-pcre=../pcre2-${PCRE_VERSION} \
    --with-zlib=../zlib-${ZLIB_VERSION} \
    --with-openssl=../openssl-${OPENSSL_VERSION} \
    --with-cc-opt="-static -Os -fdata-sections -ffunction-sections -fPIC" \
    --with-ld-opt="-static -Wl,--gc-sections"

make -j$(nproc)
make install

# Verify it's truly static
echo "Checking if binary is static..."
ldd /nginx/sbin/nginx || echo "Great! No shared library dependencies."

# Create desired directory structure for copying into scratch
mkdir -p /nginx/conf.d /nginx/stream.d/ /nginx/certs /var/www /var/log/nginx

# Shrink size as much as possible
ORIG_SIZE=$(wc -c < /nginx/sbin/nginx)
echo "Stripping symbols"
strip --strip-all /nginx/sbin/nginx
STRIPPED_SIZE=$(wc -c < /nginx/sbin/nginx)
echo "Applying UPX compression..."
upx --best --ultra-brute /nginx/sbin/nginx
UPX_SIZE=$(wc -c < /nginx/sbin/nginx)

echo "Original nginx binary size: $ORIG_SIZE bytes ($(numfmt --to=iec-i --suffix=B $ORIG_SIZE))"
echo "Size reduction from stripping: $(($ORIG_SIZE - $STRIPPED_SIZE)) bytes ($(numfmt --to=iec-i --suffix=B $(($ORIG_SIZE - $STRIPPED_SIZE))))"
echo "Size reduction from stripped->UPX: $(($STRIPPED_SIZE - $UPX_SIZE)) bytes ($(numfmt --to=iec-i --suffix=B $(($STRIPPED_SIZE - $UPX_SIZE))))"
echo "Final nginx binary size: $UPX_SIZE bytes ($(numfmt --to=iec-i --suffix=B $UPX_SIZE))"
echo "Total size reduction: $(($ORIG_SIZE - $UPX_SIZE)) bytes ($(numfmt --to=iec-i --suffix=B $(($ORIG_SIZE - $UPX_SIZE))))"

# Create a minimal HTML file
echo "<html><body><h1>micro-nginx</h1></body></html>" > /var/www/index.html

echo "Build completed successfully!"
