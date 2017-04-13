#!/usr/bin/perl

# (C) Sean Parkinson
# (C) wolfSSL, Inc.

# Tests for http ssl module.

###############################################################################

use warnings;
use strict;

use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib 'lib';
use Test::Nginx;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

eval { require IO::Socket::SSL; };
plan(skip_all => 'IO::Socket::SSL not installed') if $@;
eval { IO::Socket::SSL::SSL_VERIFY_NONE(); };
plan(skip_all => 'IO::Socket::SSL too old') if $@;

my $t = Test::Nginx->new()->has(qw/http http_ssl rewrite/)
	->has_daemon('openssl');

$t->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

events {
}

http {
    %%TEST_GLOBALS_HTTP%%

    ssl_certificate_key localhost.key;
    ssl_certificate localhost.crt;
    ssl_session_tickets off;

    server {
        listen       127.0.0.1:8080 ssl;
        server_name  localhost;

        ssl_certificate_key localhost.key;
        ssl_certificate localhost.crt;
        ssl_session_cache shared:SSL:1m;

        ssl_ciphers  ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA;

        location /cipher {
            return 200 "body $ssl_cipher";
        }
    }
}

EOF

$t->write_file('openssl.conf', <<EOF);
[ req ]
encrypt_key = no
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
EOF

my $d = $t->testdir();

$t->write_file('ca.conf', <<EOF);
[ ca ]
default_ca = myca

[ myca ]
new_certs_dir = $d
database = $d/certindex
default_md = sha256
policy = myca_policy
serial = $d/certserial
default_days = 3

[ myca_policy ]
commonName = supplied
EOF

$t->write_file('certserial', '1000');
$t->write_file('certindex', '');

system("openssl ecparam -genkey -name prime256v1 -out '$d/issuer.key' "
        . ">>$d/openssl.out 2>&1") == 0
        or die "Can't create ECC public key for issuer: $!\n";
system('openssl req -x509 -new '
	. "-config '$d/openssl.conf' -subj '/CN=issuer/' "
	. "-out '$d/issuer.crt' -key '$d/issuer.key' "
	. ">>$d/openssl.out 2>&1") == 0
	or die "Can't create certificate for issuer: $!\n";

system("openssl ecparam -genkey -name prime256v1 -out '$d/subject.key' "
        . ">>$d/openssl.out 2>&1") == 0
        or die "Can't create ECC public key for subject: $!\n";
system("openssl req -new "
	. "-config '$d/openssl.conf' -subj '/CN=subject/' "
	. "-out '$d/subject.csr' -key '$d/subject.key' "
	. ">>$d/openssl.out 2>&1") == 0
	or die "Can't create certificate for subject: $!\n";

system("openssl ca -batch -config '$d/ca.conf' "
	. "-keyfile '$d/issuer.key' -cert '$d/issuer.crt' "
	. "-subj '/CN=subject/' -in '$d/subject.csr' -out '$d/subject.crt' "
	. ">>$d/openssl.out 2>&1") == 0
	or die "Can't sign certificate for subject: $!\n";

foreach my $name ('localhost') {
        system("openssl ecparam -genkey -name prime256v1 "
                . "-out '$d/$name.key' >>$d/openssl.out 2>&1") == 0
                or die "Can't create ECC public key for $name: $!\n";
	system('openssl req -x509 -new '
		. "-config '$d/openssl.conf' -subj '/CN=$name/' "
		. "-out '$d/$name.crt' -key '$d/$name.key' "
		. ">>$d/openssl.out 2>&1") == 0
		or die "Can't create certificate for $name: $!\n";
}

my $ctx = new IO::Socket::SSL::SSL_Context(
	SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
	SSL_session_cache_size => 100);

$t->try_run('no ssl_ecc')->plan(1);

###############################################################################

like(get('/cipher', 8080), qr/^body [\w-]+$/m, 'cipher');

###############################################################################

sub get {
	my ($uri, $port) = @_;
	my $s = get_ssl_socket($ctx, port($port)) or return;
	http_get($uri, socket => $s);
}

sub cert {
	my ($uri, $port) = @_;
	my $s = get_ssl_socket(undef, port($port),
		SSL_cert_file => "$d/subject.crt",
		SSL_key_file => "$d/subject.key") or return;
	http_get($uri, socket => $s);
}

sub get_ssl_socket {
	my ($ctx, $port, %extra) = @_;
	my $s;

	eval {
		local $SIG{ALRM} = sub { die "timeout\n" };
		local $SIG{PIPE} = sub { die "sigpipe\n" };
		alarm(2);
		$s = IO::Socket::SSL->new(
			Proto => 'tcp',
			PeerAddr => '127.0.0.1',
			PeerPort => $port,
			SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
			SSL_reuse_ctx => $ctx,
			SSL_error_trap => sub { die $_[1] },
			%extra
		);
		alarm(0);
	};
	alarm(0);

	if ($@) {
		log_in("died: $@");
		return undef;
	}

	return $s;
}

###############################################################################
