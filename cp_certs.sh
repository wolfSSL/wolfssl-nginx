#!/bin/sh

CONF_DIR=conf
WOLFSSL_CERTS_DIR=../wolfssl/certs

cp $WOLFSSL_CERTS_DIR/ca-ecc-cert.pem $CONF_DIR/ca-cert-ecc.pem
cp $WOLFSSL_CERTS_DIR/ca-cert.pem $CONF_DIR/ca-cert.pem
cp $WOLFSSL_CERTS_DIR/server-ecc.pem $CONF_DIR/cert-ecc.pem
cp $WOLFSSL_CERTS_DIR/ecc-key.pem $CONF_DIR/cert-ecc.key
cp $WOLFSSL_CERTS_DIR/ecc-keyPkcs8.pem $CONF_DIR/cert-ecc-p8.key
cp $WOLFSSL_CERTS_DIR/ecc-privkey.pem $CONF_DIR/cert-ecc-priv.key
cp $WOLFSSL_CERTS_DIR/server-key.pem $CONF_DIR/cert.key
cp $WOLFSSL_CERTS_DIR/server-cert.pem $CONF_DIR/cert.pem
cp $WOLFSSL_CERTS_DIR/client-cert.pem $CONF_DIR/client-cert.pem
cp $WOLFSSL_CERTS_DIR/client-key.pem $CONF_DIR/client-key.pem
cp $WOLFSSL_CERTS_DIR/crl/crl.pem $CONF_DIR/crl.pem
cp $WOLFSSL_CERTS_DIR/crl/crl.revoked $CONF_DIR/crl-revoked.pem
cp $WOLFSSL_CERTS_DIR/dh2048.pem $CONF_DIR/dhparams.pem
cp $WOLFSSL_CERTS_DIR/dh2048.pem $CONF_DIR/dhparams.pem
cp $WOLFSSL_CERTS_DIR/ocsp/server2-cert.pem $CONF_DIR/ocsp-bad-cert.pem
cp $WOLFSSL_CERTS_DIR/ocsp/server2-key.pem $CONF_DIR/ocsp-bad-key.pem
cp $WOLFSSL_CERTS_DIR/ocsp/server1-cert.pem $CONF_DIR/ocsp-good-cert.pem
cp $WOLFSSL_CERTS_DIR/ocsp/server1-key.pem $CONF_DIR/ocsp-good-key.pem
cp $WOLFSSL_CERTS_DIR/ocsp/root-ca-cert.pem $CONF_DIR/ocsp-root-resp-cert.pem
cp $WOLFSSL_CERTS_DIR/ocsp/index-intermediate1-ca-issued-certs.txt $CONF_DIR/ocsp-index.txt
cp $WOLFSSL_CERTS_DIR/ocsp/root-ca-cert.pem $CONF_DIR/ocsp-root-ca-cert.pem
cp $WOLFSSL_CERTS_DIR/ocsp/ocsp-responder-cert.pem $CONF_DIR/ocsp-responder-cert.pem
cp $WOLFSSL_CERTS_DIR/ocsp/ocsp-responder-key.pem $CONF_DIR/ocsp-responder-key.pem
cp $WOLFSSL_CERTS_DIR/ocsp/intermediate1-ca-cert.pem $CONF_DIR/ocsp-intermediate-ca-cert.pem


