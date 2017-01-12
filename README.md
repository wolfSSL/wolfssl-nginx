# wolfssl-nginx

## wolfSSL Support in Nginx

wolfSSL is supported in Nginx. There are minor changes to the Nginx code base
and recompilation is required.

The last tested versions:
 - wolfSSL 3.10
 - Nginx 1.11.7

### Install

First you will need both Nginx and wolfSSL source code.
They can be obtained with the following commands:
 - Nginx: git clone https://github.com/nginx/nginx.git
 - wolfSSL: git clone https://github.com/wolfSSL/wolfssl.git

First build and install wolfSSL. The default installation directory is: /usr/local.

To enable wolfSSL support in Nginx the source code must be patched:
 1. Change into Nginx source directory.
 2. Apply patch: git apply <wolfssl-nginx>/nginx.diff

Now rebuild Nginx and install:
 1. Configure Nginx with one of the two commands:
   - ./configure --with-wolfssl=/usr/local --with-http_ssl_module
   - ./auto/configure --with-wolfssl=/usr/local --with-http_ssl_module
 2. Build Nginx: make
 3. Install Nginx: sudo make install

### Testing

There is a test script to ensure that the Nginx is working correctly with wolfSSL. OpenSSL's superapp is required for OCSP Stapling testing. To test:
 1. Change into wolfssl-nginx directory.
 2. Run the script: ./test.sh
 3. When working, the number of FAIL and UNKNOWN will be 0.

Testing is only supported on Linux with bash.

