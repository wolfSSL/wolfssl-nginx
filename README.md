# wolfssl-nginx

## wolfSSL Support in Nginx

wolfSSL is supported in Nginx. There are minor changes to the Nginx code base
and recompilation is required.

The tested versions:
 - wolfSSL 3.14
 - wolfSSL 3.13.0 (with patch applied: wolfssl-3.13.0-nginx.patch)
 - Nginx 1.14.0
 - Nginx 1.13.12
 - Nginx 1.13.8
 - Nginx 1.13.2
 - Nginx 1.13.0
 - Nginx 1.12.2
 - Nginx 1.12.1
 - Nginx 1.12.0
 - Nginx 1.11.13
 - Nginx 1.11.10
 - Nginx 1.11.7
 - Nginx 1.10.3

### Building

First you will need Nginx source package and wolfSSL source code.

Now build and install wolfSSL.
Please make sure to configure wolfSSL with ```./configure --enable-nginx```.
The default installation directory is:
    /usr/local.

To enable wolfSSL support in Nginx the source code must be patched:
 1. Change into the Nginx source directory.
 2. Apply patch: patch -p1 < <wolfssl-nginx>/nginx-<nginx-version>-wolfssl.patch

Now rebuild Nginx:
 1. Configure Nginx with this command (extra options may be added as required):
   - ./configure --with-wolfssl=/usr/local --with-http_ssl_module
 2. Build Nginx: make

### Testing

Nginx has a repository of tests that can be obtained with the following command:
 - git clone https://github.com/nginx/nginx-tests.git

To run the tests see the README. Tests are expected to pass with exceptions. An example of runnning the tests:
 1. Change into nginx-tests directory.
 2. Run tests: TEST_NGINX_BINARY=../nginx-<nginx-version>-wolfssl/objs/nginx prove .

There will be failures of SSL tests for the following reasons:
 - using non-default, insecure cipher suites, multiple certificate chains not supported (ssl_certificate.t)
 - using non-default, insecure cipher suites (ssl_stapling.t)

Note: the file ssl_ecc.t in wolfssl-nginx can be used with the Nginx test
system.


There are additional tests available in wolfssl-nginx. These are in addition
to the Nginx tests. The OpenSSL's superapp is required for OCSP Stapling
testing. To test:
 1. Change into wolfssl-nginx directory.
 2. Run the script: ./test.sh (If using IPv6 then set IPV6=yes.)
 3. When working, the number of FAIL and UNKNOWN will be 0.

Testing is only supported on Linux with bash.

### License

This work is licensed under GPLv3; see [LICENSE](https://github.com/wolfssl/wolfssl-nginx/blob/master/LICENSE) for details.

