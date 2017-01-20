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

Now build and install wolfSSL. The default installation directory is:
    /usr/local.

To enable wolfSSL support in Nginx the source code must be patched:
 1. Change into Nginx source directory.
 2. Apply patch: git apply <wolfssl-nginx>/nginx.diff

Now rebuild Nginx:
 1. Configure Nginx with this command (extra options may be added as required):
   - ./auto/configure --with-wolfssl=/usr/local --with-http_ssl_module
 2. Build Nginx: make

Note: The source package may also be used. In this case the configuration
program is: ./configure

### Testing

Nginx has a repository of tests that can be obtained with the following command:
 - git clone https://github.com/nginx/nginx-tests.git

To run the tests see the README. All tests are expected to pass.
There will be skips of SSL tests for the following reasons:
 - no multiple certificates (ssl_certificate.t)
 - many not work, leaves coredump (ssl_engine_keys.t)

Note: the file ssl_ecc.t in wolfssl-nginx can be used with the Nginx test
system.

There are additional tests available in wolfssl-nginx. These are in addition
to the Nginx tests. The OpenSSL's superapp is required for OCSP Stapling
testing. To test:
 1. Change into wolfssl-nginx directory.
 2. Run the script: ./test.sh
 3. When working, the number of FAIL and UNKNOWN will be 0.

Testing is only supported on Linux with bash.

