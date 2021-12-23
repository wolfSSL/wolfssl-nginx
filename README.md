# wolfssl-nginx

## wolfSSL Support in Nginx

wolfSSL is supported in Nginx. There are minor changes to the Nginx code base
and recompilation is required.

The tested versions:
 - wolfSSL 5.1.0
 - wolfSSL 3.14
 - wolfSSL 3.13.0 (with patch applied: wolfssl-3.13.0-nginx.patch)
 - Nginx 1.21.4
 - Nginx 1.19.6
 - Nginx 1.17.5
 - Nginx 1.16.1
 - Nginx 1.15.0
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
 - Nginx 1.7.7

### Building

First you will need Nginx source package and wolfSSL source code.

Now build and install wolfSSL.
Please make sure to configure wolfSSL with ```./configure --prefix=/usr/local --enable-nginx```.

To enable wolfSSL support in Nginx the source code must be patched:
 1. Change into the Nginx source directory.
 2. Apply patch: patch -p1 < <wolfssl-nginx>/nginx-<nginx-version>-wolfssl.patch

Now rebuild Nginx:
 1. Configure Nginx with this command (extra options may be added as required):
   - ./configure --with-wolfssl=/usr/local --with-http_ssl_module
 2. Build Nginx: make

### Testing

#### `nginx-tests`

Nginx has a repository of tests that can be obtained with the following command:
 - git clone https://github.com/nginx/nginx-tests.git

To run the tests see the `nginx-tests` README. Tests are expected to pass with 
exceptions. An example of running the tests:
 1. Change into the `nginx-tests` directory.
 2. Run tests: `TEST_NGINX_BINARY=../nginx-<nginx-version>-wolfssl/objs/nginx prove .`

There are patch sets available in the `nginx-tests-patches` directory for the
nginx-tests testsuite. These patches fix issues with running the tests against
a version of Nginx that was compiled with wolfSSL. They also add some further
debug capabilities. The patch file names are in the structure:

```
<year>-<month>-<day>-<nginx-tests commit>.patch
```

The patch should be applied before running any tests using `patch -p1 < <path/to/patch>`.
The date and commit hash in the file name refer to the version of nginx-tests
that the patch was prepared for.

#### Debugging `nginx-tests`

To use the new gdbserver feature, the Nginx configuration of the test needs to
be changed to include `master_process off;`. This can be done for all tests
with the following `sed` command. Please note that some tests rely on on a
master and worker process structure. Please check if the test passes without
configuration changes first.

```
sed -e 's/daemon off;/master_process off;\ndaemon off;/g' -i *.t
```

For an easy way to remove all of the `master_process off;` changes, please use
this `perl` command: 

```
perl -0777 -i -pe 's/master_process off;\n//g' *.t
```

#### `nginx-tests` Caveats

Without applying the appropriate patchset, there will be failures of SSL tests
for the following reasons:
 - using non-default, insecure cipher suites, multiple certificate chains not
   supported (ssl_certificate.t)
 - using non-default, insecure cipher suites (ssl_stapling.t)

Note: the file ssl_ecc.t in wolfssl-nginx can be used with the Nginx test
system.
Note: the file ssl_stapling.t.patch can be used to patch the ssl_stapling.t
file in nginx-tests to work with wolfSSL. The version available in the testing
repository uses different certs on the same server. This is not supported
by wolfSSL so this patch moves the certs to separate server instances.

#### Internal Tests

There are additional tests available in wolfssl-nginx. These are in addition
to the Nginx tests. The OpenSSL's superapp is required for OCSP Stapling
testing. To test:
 1. Change into wolfssl-nginx directory.
 2. Run the script: ./test.sh (If using IPv6 then set IPV6=yes.)
 3. When working, the number of FAIL and UNKNOWN will be 0.

Testing is only supported on Linux with bash.

## Post-Quantum Algorithms

Starting with wolfSSL version 5.1.0 and nginx version 1.21.4, You can now enable the integration of liboqs in wolfSSL thus enabling post-quantum algorithms for your HTTPS connections over TLS 1.3. In this case, the web server will be nginx with wolfSSL and the web client will be curl with wolfSSL.

First, you will need to build the OpenQuantumSafe group's liboqs and their fork of OpenSSL to generate the certificate chain that uses the post-quantum FALCON signature scheme. Instructions for that are in wolfSSL git repository's INSTALL file. Note that when you generate your certificates, you will need to add your IP address as a subject alternative name. See here for more details: https://www.openssl.org/docs/manmaster/man5/x509v3_config.html

When building wolfSSL, you will need to add a couple extra flags:

```
./configure --prefix=/usr/local --enable-nginx --with-liboqs
make all
make check
sudo make install
```

Now, you can continue on with the instructions for building nginx above.

Now that all the software is built and installed, you will need to add a section in the nginx.conf file to enable TLS 1.3 and use the correct certificates. Edit `/usr/local/nginx/conf/nginx.conf`. Nginx's install process should have put a default version there. Search for the section with the title `HTTPS server` and replace that section with the following:

```
    server {
        listen                    443 ssl;
        server_name               localhost;

        ssl_certificate           /path/to/falcon_level5_entity_cert.pem;
        ssl_certificate_key       /path/to/falcon_level5_entity_key.pem;

        ssl_session_cache         shared:SSL:1m;
        ssl_session_timeout       5m;

        ssl_protocols             TLSv1.3;
        ssl_ciphers               TLS_AES_256_GCM_SHA384;
        ssl_prefer_server_ciphers on;

        location / {
            root   html;
            index  index.html index.htm;
        }
    }
```

NOTE: You will need to change the path of the certificate and key.

You can now execute the nginx web server by doing the following:

```
sudo /usr/local/nginx/sbin/nginx
```

Check `/usr/local/nginx/logs/error.log` to see if there were any errors and ensure that `/usr/local/nginx/logs/nginx.pid` exists. It is created upon successful launch of the server daemon process. 

NOTE: You will need to change the path of the root certificate and use your IP address.

## Licensing

wolfSSL and wolfCrypt are either licensed for use under the GPLv3 (or at your option any later version) or a standard commercial license. For users who cannot use wolfSSL under GPLv3 (or any later version), a commercial license to wolfSSL and wolfCrypt is available. For license inquiries, please contact wolfSSL Inc. directly at licensing@wolfssl.com.

The NGINX patches in this repository are licensed under their respective project licenses.

## Support

For support or build issues, please contact the wolfSSL support team at support@wolfssl.com.
