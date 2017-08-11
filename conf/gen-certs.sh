#!/bin/sh

OPENSSL_CONF="./ca/openssl.conf"
CA_CONF="./ca/ca.conf"

if [ -d ca ]; then
    rm -rf ca
fi

mkdir ca
echo "1000" >./ca/certserial
echo -n >./ca/certindex
cat << EOF >$OPENSSL_CONF
[ req ]
encrypt_key = no
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
[ ca ]
default_ca = myca
[ myca ]
default_days = 3650
[ usr_cert ]
basicConstraints = CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints = CA:true
EOF
cat << EOF >$CA_CONF
[ ca ]
default_ca = myca

[ myca ]
new_certs_dir = ca
database = ca/certindex
default_md = sha256
policy = myca_policy
serial = ca/certserial
default_days = 3650

[ myca_policy ]
commonName = supplied

[ usr_cert ]
basicConstraints = CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints = CA:true
keyUsage = nonRepudiation,digitalSignature,keyCertSign
extendedKeyUsage = serverAuth
EOF

ISSUER=
for NAME in "ecc-3-root" "ecc-3-ca" "ecc-3-leaf"
do
    openssl ecparam -genkey -name prime256v1 -out "./${NAME}.key"
    RET=$?
    if [ "$RET" != "0" ]; then
        echo "Can't create ECC public key for ${NAME}: $RET"
        exit 1
    fi

    EXT=v3_ca
    if [ $NAME = "ecc-3-leaf" ]; then
        EXT=usr_cert
    fi

    if [ "$ISSUER" = "" ]; then
        openssl req -x509 -new \
            -config $OPENSSL_CONF -subj "/CN=${NAME}/" \
            -out "./${NAME}.crt" -key "./${NAME}.key" \
            -extensions $EXT -days 3650 \
            >/dev/null 2>&1
        RET=$?
        if [ "$RET" != "0" ]; then
            echo "Can't create certificate for ${NAME}: $RET"
            exit 1
        fi
    else
        openssl req -new \
            -config $OPENSSL_CONF -subj "/CN=${NAME}/" \
            -out "./ca/${NAME}.csr" -key "./${NAME}.key" \
            >/dev/null 2>&1
        RET=$?
        if [ "$RET" != "0" ]; then
            echo "Can't create certificate for ${NAME}: $RET"
            exit 1
        fi

        openssl req -x509 -new \
            -config $OPENSSL_CONF -subj "/CN=${NAME}/" \
            -out "./${NAME}.crt" -key "./${NAME}.key" \
            -extensions $EXT \
            >/dev/null 2>&1
        RET=$?
        if [ "$RET" != "0" ]; then
            echo "Can't create certificate for ${NAME}: $RET"
            exit 1
        fi
        openssl ca -batch -config $CA_CONF \
            -keyfile "./${ISSUER}.key" -cert "./${ISSUER}.crt" \
            -subj "/CN=${NAME}/" -in "./ca/${NAME}.csr" -out "./${NAME}.crt" \
            -extensions $EXT \
            >/dev/null 2>&1
        RET=$?
        if [ "$RET" != "0" ]; then
            echo "Can't sign certificate for ${NAME}: $RET"
            exit 1
        fi

        BUNDLE="$NAME.crt $BUNDLE"
    fi

    echo "${NAME}.crt"
    ISSUER=$NAME
done

rm -f ecc-3-caleaf.crt
for FILE in $BUNDLE
do
    cat $FILE >>ecc-3-caleaf.crt
done

