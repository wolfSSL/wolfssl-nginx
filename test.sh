#!/bin/bash



NGINX_SRC="../nginx"
if [ "$NGINX_BIN" = "" ]; then
    NGINX_BIN="${NGINX_SRC}/objs/nginx"
fi
if [ "$WOLFSSL_SOURCE" = "" ]; then
    WOLFSSL_SOURCE="../wolfssl"
fi
WOLFSSL_CLIENT="./examples/client/client"
NGINX_CONF="./conf/nginx.conf"
NGINX_TLS13_CONF="./conf/nginx_tls13.conf"
CLIENT_TMP="/tmp/nginx_client.$$"
SERVER_TMP="/tmp/nginx_server.$$"
OCSP_GOOD="ocsp-good-status.der"
OCSP_BAD="ocsp-bad-status.der"
WN_PATH=`pwd`
WN_OCSP_GOOD="$WN_PATH/conf/$OCSP_GOOD"
WN_OCSP_BAD="$WN_PATH/conf/$OCSP_BAD"
WN_LOGS="$WN_PATH/logs"
WN_ERROR_LOG="$WN_LOGS/error.log"
HOST="127.0.0.1"
if [ "$IPV6" != "" ]; then
    HOST="::ffff:127.0.0.1"
fi


while [ $# -gt 0 ]
do
    case $1 in
        -tls13)
            TLS13=1
            NGINX_CONF=$NGINX_TLS13_CONF
            ;;
        *)
            echo "Unrecognized option: $1"
            exit 1
            ;;
    esac
    shift
done


if [ ! -f $NGINX_BIN ]; then
    echo "Could not find Nginx exe: ${NGINX_BIN}"
    echo "Stopping - FAIL"
    exit 1
fi
echo "Ngninx binary: $NGINX_BIN"
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
OPENSSL=`which openssl`
if [ "$?" = "1" ]; then
    echo "Could not find openssl superapp"
    echo "Stopping - FAIL"
    exit 1
fi
echo "OpenSSL superapp found: $OPENSSL"
echo

if [ ! -d $WN_LOGS ]; then
    echo "Making directory: ${WN_LOGS}"
    mkdir ${WN_LOGS}
fi

# Number of minutes OCSP responses will be valid for
VALID_MIN=60

declare -a EXPECT
declare -a EXPECT_SERVER
declare -a EXP

SERVER_PID=0
OCSP_PID=0

PASS=0
FAIL=0
UNKNOWN=0

run_nginx() {
    # valgrind --leak-check=full
    echo ${NGINX_BIN} -p ${WN_PATH} \
        -c $NGINX_CONF \
        -g "error_log ${WN_ERROR_LOG} debug;" \
        ${NGINX_OPTS}
    ${NGINX_BIN} -p ${WN_PATH} \
        -c $NGINX_CONF \
        -g "error_log ${WN_ERROR_LOG} debug;" \
        ${NGINX_OPTS}
    RES=$?
}

do_cleanup() {
    echo "# In cleanup"

    NGINX_OPTS="-s stop"
    run_nginx

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

    cd $WN_PATH
    rm -rf client_body_temp fastcgi_temp proxy_temp scgi_temp uwsgi_temp
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
    ${WOLFSSL_CLIENT} -r -g -p $PORT -h $HOST $OPTS >$CLIENT_TMP 2>&1

    echo "# Client Output"
    LOG=$CLIENT_TMP
    EXP=("${EXPECT[@]}")
    check_log
}
client_test() {
    OPTS="$OPTS -r"
    client
}
stapling_test() {
    OPTS="$OPTS -C -A ${WN_PATH}/conf/ocsp-root-ca-cert.pem -W 1"
    client
}

# Start the OSCP responder and generate the response files
${OPENSSL} ocsp -port 22221 -nmin ${VALID_MIN} -index ${WN_PATH}/conf/ocsp-index.txt -rsigner ${WN_PATH}/conf/ocsp-responder-cert.pem -rkey ${WN_PATH}/conf/ocsp-responder-key.pem -CA ${WN_PATH}/conf/ocsp-intermediate-ca-cert.pem >/dev/null 2>&1 &
OCSP_PID=$!

# Generate OCSP response file that indicates certificate is good.
${OPENSSL} ocsp -issuer ${WN_PATH}/conf/ocsp-intermediate-ca-cert.pem -cert ${WN_PATH}/conf/ocsp-good-cert.pem -url http://localhost:22221 -resp_text -respout ${WN_OCSP_GOOD} -no_nonce >/dev/null 2>&1

# Generate OCSP response file that indicates certificate is revoked.
${OPENSSL} ocsp -issuer ${WN_PATH}/conf/ocsp-intermediate-ca-cert.pem -cert ${WN_PATH}/conf/ocsp-bad-cert.pem -url http://localhost:22221 -resp_text -respout ${WN_OCSP_BAD} -no_nonce >/dev/null 2>&1

if [ ! -f $WN_OCSP_GOOD ]; then
    echo "Could not find OCSP output file: ${WN_OCSP_GOOD}"
    echo "Stopping - FAIL"
    exit 1
fi
if [ ! -f $WN_OCSP_BAD ]; then
    echo "Could not find OCSP output file: ${WN_OCSP_BAD}"
    echo "Stopping - FAIL"
    exit 1
fi

echo "Stopping Nginx ..."
NGINX_OPTS="-s stop"
run_nginx
echo "Starting Nginx ..."
# Start Nginx
NGINX_OPTS=
run_nginx
if [ "$RES" != "0" ]; then
    echo "Failed to start Nginx"
    exit 1
fi

# Default certificate, DH KEA
echo
echo '#'
echo '# DH Key Exchange'
echo '#'
PORT=11443
echo "# Port: $PORT"
OPTS=
EXPECT=("2048" "TLS_DHE_RSA_WITH_AES_128_GCM_SHA256" "HTTP/1.1 200 OK" "resume response")
client_test
# Default certificate, DH, verify client
echo
echo '#'
echo '# DH Key Exchange verify client'
echo '#'
PORT=11444
echo "# Port: $PORT"
OPTS="-x"
EXPECT=("400 No required SSL certificate was sent")
client_test
# Default certificate, ECDH with SECP384R1
echo
echo '#'
echo '# ECDH Key Exchange: SECP384R1'
echo '#'
PORT=11445
echo "# Port: $PORT"
OPTS=
EXPECT=("SECP384R1" "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256" "HTTP/1.1 200 OK")
client_test
# ECC certificate, ECDH with default curve (prime256v1)
echo
echo '#'
echo '# ECC Certificate, ECDH Key Exchange: default curve (prime256v1)'
echo '#'
PORT=11446
echo "# Port: $PORT"
OPTS="-A certs/ca-ecc-cert.pem"
EXPECT=("SECP256R1" "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256" "HTTP/1.1 200 OK")
client_test
if [ "$TLS13" != "" ]; then
  # TLS v1.3
  echo
  echo '#'
  echo '# TLS v1.3 client connecting to nginx server'
  echo '#'
  PORT=11447
  echo "# Port: $PORT"
  OPTS="-v 4"
  EXPECT=("SECP256R1" "TLS_AES_128_GCM_SHA256" "HTTP/1.1 200 OK")
  client_test
fi
# Session tickets file
echo
echo '#'
echo '# Session ticket file'
echo '#'
PORT=11450
echo "# Port: $PORT"
OPTS=
EXPECT=("Session Ticket CB" "HTTP/1.1 200 OK")
client_test

echo
echo '#'
echo '# Session cache off'
echo '#'
PORT=11455
echo "# Port: $PORT"
OPTS=
EXPECT=("didn't reuse session id!!!" "HTTP/1.1 200 OK")
client_test
echo
echo '#'
echo '# Session cache none'
echo '#'
PORT=11456
echo "# Port: $PORT"
OPTS=
EXPECT=("didn't reuse session id!!!" "HTTP/1.1 200 OK")
client_test
echo
echo '#'
echo '# Session cache builtin'
echo '#'
PORT=11457
echo "# Port: $PORT"
OPTS=
if [ "$TLS13" != "" ]; then
  EXPECT=("HTTP/1.1 200 OK")
else
  EXPECT=("reused session id" "HTTP/1.1 200 OK")
fi
client_test

# Proxy to localhost:11111 - DHE-RSA
echo
echo '#'
echo '# Proxy - DHE-RSA'
echo '#'
PORT=11460
echo "# Port: $PORT"
OPTS=
SERVER_OPTS=
EXPECT=("HTTP/1.1 200 OK" "Welcome to wolf")
client_test
# Proxy to localhost:11111 - ECDHE-RSA
echo
echo '#'
echo '# Proxy - ECDHE-RSA'
echo '#'
PORT=11461
echo "# Port: $PORT"
OPTS=
SERVER_OPTS=
EXPECT=("HTTP/1.1 200 OK" "Welcome to wolf")
client_test
# Proxy to localhost:11111 - ECDHE-ECDSA
echo
echo '#'
echo '# Proxy - ECDHE-ECDSA'
echo '#'
PORT=11462
echo "# Port: $PORT"
OPTS=
SERVER_OPTS="-c certs/server-ecc.pem -k certs/ecc-key.pem"
EXPECT=("HTTP/1.1 200 OK" "Welcome to wolf")
client_test
# Proxy to localhost:11111 - ECDHE-ECDSA
echo
echo '#'
echo '# Proxy - ECDHE-ECDSA'
echo '#'
PORT=11463
echo "# Port: $PORT"
OPTS=
SERVER_OPTS="-c certs/server-ecc.pem -k certs/ecc-key.pem"
EXPECT=("HTTP/1.1 200 OK" "Welcome to wolf")
client_test
# Proxy to localhost:11111 - ECDHE-ECDSA
echo
echo '#'
echo '# Proxy - ECDHE-ECDSA'
echo '#'
PORT=11464
echo "# Port: $PORT"
OPTS=
SERVER_OPTS="-c certs/server-ecc.pem -k certs/ecc-key.pem"
EXPECT=("HTTP/1.1 502")
client_test
# Proxy to localhost:11111 - Revoked certificate in CRL
echo
echo '#'
echo '# Proxy - Revoked certificate in CRL'
echo '#'
PORT=11465
echo "# Port: $PORT"
OPTS=
SERVER_OPTS=
EXPECT=("HTTP/1.1 502")
client_test

# OCSP Stapling
# Good certificate
echo
echo '#'
echo '# OCSP Stapling - Good Certificate (Using OCSP Responder)'
echo '#'
PORT=11470
echo "# Port: $PORT"
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
echo "# Port: $PORT"
OPTS=
EXPECT=("err" "360")
stapling_test
stapling_test
# Good certificate - response file
echo
echo '#'
echo '# OCSP Stapling - Good Certificate (Using pre-generated file)'
echo '#'
PORT=11472
echo "# Port: $PORT"
OPTS=
EXPECT=("HTTP/1.1 200 OK")
stapling_test
# Revoked certificate - response file
echo
echo '#'
echo '# OCSP Stapling - Revoked Certificate (Using pre-generated file)'
echo '#'
PORT=11473
echo "# Port: $PORT"
OPTS=
EXPECT=("err" "360")
stapling_test
# No certificate for verification of OCSP response
echo
echo '#'
echo '# OCSP Stapling - Using OCSP Responder but no cert to verify'
echo '#'
PORT=11474
echo "# Port: $PORT"
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

