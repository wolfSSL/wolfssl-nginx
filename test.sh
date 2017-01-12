#!/bin/bash

INSTALL_NGINX="/usr/local/nginx"
INSTALL_NGINX_CONF="$INSTALL_NGINX/conf"
INSTALL_NGINX_CONF_BACKUP="$INSTALL_NGINX/conf_backup"
INSTALL_NGINX_BIN="$INSTALL_NGINX/sbin"
WOLFSSL_SOURCE="../wolfssl"
WOLFSSL_CLIENT="./examples/client/client"
WOLFSSL_SERVER="./examples/server/server"
NGINX_CONF="./conf"
CLIENT_TMP="/tmp/nginx_client.$$"
SERVER_TMP="/tmp/nginx_server.$$"
WN_PATH=`pwd`

echo "Ngninx Install directory: $INSTALL_NGINX"
if [ ! -d $INSTALL_NGINX_CONF ]; then
    echo "Could not find Nginx conf directory: ${INSTALL_NGINX_CONF}"
    echo "Stopping - FAIL"
    exit 1
fi
if [ ! -e $INSTALL_NGINX_BIN/nginx ]; then
    echo "Could not find Nginx exe: ${INSTALL_NGINX_BIN}/nginx"
    echo "Stopping - FAIL"
    exit 1
fi
echo "wolfSSL Source directory: $WOLFSSL_SOURCE"
if [ ! -d $WOLFSSL_SOURCE ]; then
    echo "Could not find wolfSSL source directory: ${WOLFSSL_SOURCE}"
    echo "Stopping - FAIL"
    exit 1
fi
echo "Changing into wolfSSL source directory"
cd $WOLFSSL_SOURCE
if [ ! -e $WOLFSSL_CLIENT ]; then
    echo "Could not find wolfSSL client: ${WOLFSSL_CLIENT}"
    echo "Stopping - FAIL"
    exit 1
fi
if [ ! -e $WOLFSSL_SERVER ]; then
    echo "Could not find wolfSSL server: ${WOLFSSL_SERVER}"
    echo "Stopping - FAIL"
    exit 1
fi
OPENSSL=`which openssl`
if [ "$?" = "1" ]; then
    echo "Could not find openssl superapp"
    echo "Stopping - FAIL"
    exit 1
fi
echo "OpenSSL superapp found: $OPENSSL"
echo

# Number of minutes OCSP responses will be valid for
VALID_MIN=1

declare -a EXPECT
declare -a EXPECT_SERVER
declare -a EXP

SERVER_PID=0
OCSP_PID=0

PASS=0
FAIL=0
UNKNOWN=0

do_cleanup() {
    echo "# In cleanup"

    sudo ${INSTALL_NGINX_BIN}/nginx -s stop

    rm -f $CLIENT_TMP
    rm -f $SERVER_TMP

    if  [ $SERVER_PID != '0' ]
    then
        echo "# Killing server"
        kill -9 $SERVER_PID
    fi
    if  [ $OCSP_PID != '0' ]
    then
        echo "# Killing OCSP responder"
        kill -9 $OCSP_PID
    fi

    if [ -e ${INSTALL_NGINX_CONF_BACKUP} ]; then
        sudo rm -rf ${INSTALL_NGINX_CONF}
        sudo mv ${INSTALL_NGINX_CONF_BACKUP} ${INSTALL_NGINX_CONF}
    fi

    cd $WN_PATH
}

do_trap() {
    echo "# Got trap"
    do_cleanup
    exit 1
}

trap do_trap INT TERM

check_log() {
    DUMP_LOG="no"
    if [ "$EXP" != "" ]; then
        for I in ${!EXP[@]}
        do
            if grep "${EXP[$I]}" $LOG; then
                echo "# PASS: Found: ${EXP[$I]}"
                echo
                PASS=$(($PASS + 1))
            else
                echo "# FAIL: Didn't find: ${EXP[$I]}"
                echo
                DUMP_LOG="yes"
                FAIL=$(($FAIL + 1))
            fi
        done
    else
        DUMP_LOG="yes"
        UNKNOWN=$(($UNKNOWN + 1))
    fi

    if [ "$DUMP_LOG" = "yes" ]; then
        cat $LOG
    fi
}

client() {
    ${WOLFSSL_CLIENT} -r -g -p $PORT $OPTS >$CLIENT_TMP 2>&1

    echo "# Client Output"
    LOG=$CLIENT_TMP
    EXP=("${EXPECT[@]}")
    check_log
}
client_test() {
    OPTS="$OPTS -r -g"
    client
}
proxy_test() {
    ${WOLFSSL_SERVER} -g -C 2 >$SERVER_TMP 2>&1 &
    SERVER_PID=$!

    client_test

    kill $SERVER_PID
    SERVER_PID=0

    echo "# Server Output"
    LOG=$SERVER_TMP
    EXP=("${EXPECT_SERVER[@]}")
    check_log
}
proxy_test_ecdsa() {
    ${WOLFSSL_SERVER} -c certs/server-ecc.pem -k certs/ecc-key.pem -g -C 2 >$SERVER_TMP 2>&1 &
    SERVER_PID=$!

    client_test

    kill $SERVER_PID
    SERVER_PID=0

    echo "# Server Output"
    LOG=$SERVER_TMP
    EXP=("${EXPECT_SERVER[@]}")
    check_log
}
stapling_test() {
    OPTS="$OPTS -g -C -A certs/ocsp/root-ca-cert.pem -W 1"
    client
}

sudo mv ${INSTALL_NGINX_CONF} ${INSTALL_NGINX_CONF_BACKUP}
sudo cp -r ${WN_PATH}/${NGINX_CONF} ${INSTALL_NGINX_CONF}

# Start the OSCP responder and generate the response files
${OPENSSL} ocsp -port 22221 -nmin ${VALID_MIN} -index certs/ocsp/index1.txt -rsigner certs/ocsp/ocsp-responder-cert.pem -rkey certs/ocsp/ocsp-responder-key.pem -CA certs/ocsp/intermediate1-ca-cert.pem >/dev/null 2>&1 &
OCSP_PID=$!

# Generate OCSP response file that indicates certificate is good.
(${OPENSSL} ocsp -issuer certs/ocsp/intermediate1-ca-cert.pem -cert certs/ocsp/server1-cert.pem -url http://localhost:22221 -resp_text -respout ocsp-good-status.der -no_nonce; sudo mv ocsp-good-status.der ${INSTALL_NGINX_CONF}/ocsp-good-status.der) >/dev/null 2>&1

# Generate OCSP response file that indicates certificate is revoked.
(${OPENSSL} ocsp -issuer certs/ocsp/intermediate1-ca-cert.pem -cert certs/ocsp/server2-cert.pem -url http://localhost:22221 -resp_text -respout ocsp-bad-status.der -no_nonce; sudo mv ocsp-bad-status.der ${INSTALL_NGINX_CONF}/ocsp-bad-status.der) >/dev/null 2>&1

echo "Starting Nginx ..."
sudo ${INSTALL_NGINX_BIN}/nginx -s stop
# Start Nginx
sudo ${INSTALL_NGINX_BIN}/nginx

# Default certificate, DH KEA
echo
echo '#'
echo '# DH Key Exchange'
echo '#'
PORT=11443
OPTS=
EXPECT=("SSL DH size is 2048 bits" "TLS_DHE_RSA_WITH_AES_128_GCM_SHA256" "HTTP/1.1 200 OK" "resume response")
client_test
# Default certificate, DH, verify client
echo
echo '#'
echo '# DH Key Exchange verify client'
echo '#'
PORT=11444
OPTS="-x"
EXPECT=("400 No required SSL certificate was sent")
client_test
# Default certificate, ECDH with SECP384R1
echo
echo '#'
echo '# ECDH Key Exchange: SECP384R1'
echo '#'
PORT=11445
OPTS=
EXPECT=("SECP384R1" "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256" "HTTP/1.1 200 OK")
client_test
# ECC certificate, ECDH with default curve (prime256v1)
echo
echo '#'
echo '# ECC Certificate, ECDH Key Exchange: default curve (prime256v1)'
echo '#'
PORT=11446
OPTS=
EXPECT=("SECP256R1" "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256" "HTTP/1.1 200 OK")
client_test
# Session tickets file
echo
echo '#'
echo '# Session ticket file'
echo '#'
PORT=11450
OPTS=
EXPECT=("Session Ticket CB" "HTTP/1.1 200 OK")
client_test

echo
echo '#'
echo '# Session cache off'
echo '#'
PORT=11455
OPTS=
EXPECT=("didn't reuse session id!!!" "HTTP/1.1 200 OK")
client_test
echo
echo '#'
echo '# Session cache none - still does it'
echo '#'
PORT=11456
OPTS=
EXPECT=("reused session id" "HTTP/1.1 200 OK")
client_test
echo
echo '#'
echo '# Session cache builtin'
echo '#'
PORT=11457
OPTS=
EXPECT=("reused session id" "HTTP/1.1 200 OK")
client_test
echo
echo '#'
echo '# Session cache timeout 1 second'
echo '#'
PORT=11458
OPTS=
EXPECT=("didn't reuse session id!!!" "HTTP/1.1 200 OK")
client_test

# Proxy to localhost:11111 - DHE-RSA
echo
echo '#'
echo '# Proxy - DHE-RSA'
echo '#'
PORT=11460
OPTS=
EXPECT=("HTTP/1.1 200 OK" "Welcome to wolf")
EXPECT_SERVER=("TLS_DHE_RSA_WITH_AES_128_GCM_SHA256")
proxy_test
# Proxy to localhost:11111 - ECDHE-RSA
echo
echo '#'
echo '# Proxy - ECDHE-RSA'
echo '#'
PORT=11461
OPTS=
EXPECT=("HTTP/1.1 200 OK" "Welcome to wolf")
EXPECT_SERVER=("TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256" "SSL reused session")
proxy_test
# Proxy to localhost:11111 - ECDHE-ECDSA
echo
echo '#'
echo '# Proxy - ECDHE-ECDSA'
echo '#'
PORT=11462
OPTS=
EXPECT=("HTTP/1.1 200 OK" "Welcome to wolf")
EXPECT_SERVER=("TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256" "SSL reused session")
proxy_test_ecdsa
# Proxy to localhost:11111 - Revoked certificate in CRL
echo
echo '#'
echo '# Proxy - Revoked certificate in CRL'
echo '#'
PORT=11465
OPTS=
EXPECT=("HTTP/1.1 502")
EXPECT_SERVER=("error = -308")
proxy_test

# OCSP Stapling
# Good certificate
echo
echo '#'
echo '# OCSP Stapling - Good Certificate (Using OCSP Responder)'
echo '#'
PORT=11470
OPTS=
EXPECT=("HTTP/1.1 200 OK")
stapling_test
stapling_test
# Revoked certificate
echo
echo '#'
echo '# OCSP Stapling - Revoked Certificate (Using OCSP Responder)'
echo '#'
PORT=11471
OPTS=
EXPECT=("err = -360")
stapling_test
stapling_test
# Good certificate - response file
echo
echo '#'
echo '# OCSP Stapling - Good Certificate (Using pre-generated file)'
echo '#'
PORT=11472
OPTS=
EXPECT=("HTTP/1.1 200 OK")
stapling_test
# Revoked certificate - response file
echo
echo '#'
echo '# OCSP Stapling - Revoked Certificate (Using pre-generated file)'
echo '#'
PORT=11473
OPTS=
EXPECT=("err = -360")
stapling_test
# No certificate for verification of OCSP response
echo
echo '#'
echo '# OCSP Stapling - Using OCSP Responder but no cert to verify'
echo '#'
PORT=11474
OPTS=
EXPECT=("HTTP/1.1 200 OK")
stapling_test
stapling_test

do_cleanup

echo
echo "##############"
echo "# PASS    : $PASS"
echo "# FAIL    : $FAIL"
echo "# UNKNOWN : $UNKNOWN"
echo "##############"

