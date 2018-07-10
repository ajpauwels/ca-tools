# Path where the CA folder containing root and intermediate CAs will be created
BASEPATH=~/tls;

# Name of the folder in the basepath that the CAs will be contained in
CA_NAME=''

# Check if openssl configuration files have been specified and select default values otherwise
if [[ -z "$ROOT_CA_OPENSSL_CONF_PATH" ]]; then
	ROOT_CA_OPENSSL_CONF_PATH=$(readlink -f ./root-openssl.conf)
fi
if [[ -z "$INTERMEDIATE_CA_OPENSSL_CONF_PATH" ]]; then
	INTERMEDIATE_CA_OPENSSL_CONF_PATH=$(readlink -f ./intermediate-openssl.conf)
fi

# Process command-line parameters
while getopts ":p:n:" opt; do
	case $opt in
		p)
			echo "Root and intermediate CAs will be installed in '$OPTARG'" >&2
			BASEPATH=$OPTARG
			;;
		n)
			CA_NAME=$OPTARG
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			;;
		:)
			echo "Option -$OPTARG requires an argument" >&2
			exit 1
			;;
	esac
done

# Check if a CA name was provided
if [[ -z "$CA_NAME" ]]; then
	echo "A CA name must be provided via the -n [CA name] command-line parameter"
	exit 1
fi

# Make the root directory structure
ROOT_CA_PATH="$BASEPATH/$CA_NAME"
mkdir -p "$ROOT_CA_PATH/certs" "$ROOT_CA_PATH/crl" "$ROOT_CA_PATH/newcerts" "$ROOT_CA_PATH/private"
chmod 700 "$ROOT_CA_PATH/private"
touch "$ROOT_CA_PATH/index.txt"
echo 1000 > "$ROOT_CA_PATH/serial"

# Make the intermediate directory structure
INTERMEDIATE_CA_PATH="$ROOT_CA_PATH/intermediate"
mkdir -p "$INTERMEDIATE_CA_PATH/certs" "$INTERMEDIATE_CA_PATH/crl" "$INTERMEDIATE_CA_PATH/csr" "$INTERMEDIATE_CA_PATH/newcerts" "$INTERMEDIATE_CA_PATH/private"
chmod 700 "$INTERMEDIATE_CA_PATH/private"
touch "$INTERMEDIATE_CA_PATH/index.txt"
echo 1000 > "$INTERMEDIATE_CA_PATH/serial"
echo 1000 > "$INTERMEDIATE_CA_PATH/crlnumber"

# Create the root CA private key
openssl genrsa -aes256 -out "$ROOT_CA_PATH/private/root.key.pem" 4096
chmod 400 "$ROOT_CA_PATH/private/root.key.pem"

# Create the root CA public certificate
openssl req -config "$ROOT_CA_OPENSSL_CONF_PATH" -key "$ROOT_CA_PATH/private/root.key.pem" -new -x509 -days 7300 -sha256 -extensions v3_ca -out "$ROOT_CA_PATH/certs/root.cert.pem"

# Create the intermediate CA private key
openssl genrsa -aes256 -out "$INTERMEDIATE_CA_PATH/private/intermediate.key.pem" 4096
chmod 400 "$INTERMEDIATE_CA_PATH/private/intermediate.key.pem"

# Create the intermediate CA certificate signing request
openssl req -config "$INTERMEDIATE_CA_OPENSSL_CONF_PATH" -key "$INTERMEDIATE_CA_PATH/private/intermediate.key.pem" -new -sha256 -out "$INTERMEDIATE_CA_PATH/csr/intermediate.csr.pem"

# Create the signed public certificate using the root certificate
openssl ca -config "$ROOT_CA_OPENSSL_CONF_PATH" -extensions v3_intermediate_ca -days 3650 -notext -md sha256 -in "$INTERMEDIATE_CA_PATH/csr/intermediate.csr.pem" -out "$INTERMEDIATE_CA_PATH/certs/intermediate.cert.pem"
chmod 444 "$INTERMEDIATE_CA_PATH/certs/intermediate.cert.pem"

# Create the certificate chain file
cat "$INTERMEDIATE_CA_PATH/certs/intermediate.cert.pem" "$ROOT_CA_PATH/certs/root.cert.pem" > "$INTERMEDIATE_CA_PATH/certs/intermediate.root.cert.pem"
chmod 444 "$INTERMEDIATE_CA_PATH/certs/intermediate.root.cert.pem"
