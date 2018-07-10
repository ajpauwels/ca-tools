# Path where the CA folder containing root and intermediate CAs will be created
BASEPATH=~/tls;

# Check if openssl configuration files have been specified and select default values otherwise
if [[ -z "$INTERMEDIATE_CA_OPENSSL_CONF_PATH" ]]; then
	INTERMEDIATE_CA_OPENSSL_CONF_PATH=$(readlink -f ./intermediate-openssl.conf)
fi

# Process command-line parameters
while getopts ":p:n:c:" opt; do
	case $opt in
		p)
			BASEPATH=$OPTARG
			;;
		n)
			CA_NAME=$OPTARG
			;;
		c)
		    CLIENT_NAME=$OPTARG
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

# Check if client name was provided
if [[ -z "$CLIENT_NAME" ]]; then
	echo "A client name must be provided via the -c [client name] command-line parameter"
	exit 1
fi

# Create path to intermediate CA
ROOT_CA_PATH="$BASEPATH/$CA_NAME"
INTERMEDIATE_CA_PATH="$ROOT_CA_PATH/intermediate"

# Inform user of intent
echo "Client certificate will be signed by $INTERMEDIATE_CA_PATH"

# Create client's private key
openssl genrsa -aes256 -out "$INTERMEDIATE_CA_PATH/private/$CLIENT_NAME.key.pem" 2048
chmod 400 "$INTERMEDIATE_CA_PATH/private/$CLIENT_NAME.key.pem"

# Create a certificate signing request for the client
openssl req -config "$INTERMEDIATE_CA_OPENSSL_CONF_PATH" -key "$INTERMEDIATE_CA_PATH/private/$CLIENT_NAME.key.pem" -new -sha256 -out "$INTERMEDIATE_CA_PATH/csr/$CLIENT_NAME.csr.pem"

# Sign the CSR using the intermediate CA
openssl ca -config "$INTERMEDIATE_CA_OPENSSL_CONF_PATH" -extensions usr_cert -days 375 -notext -md sha256 -in "$INTERMEDIATE_CA_PATH/csr/$CLIENT_NAME.csr.pem" -out "$INTERMEDIATE_CA_PATH/certs/$CLIENT_NAME.cert.pem"
chmod 444 "$INTERMEDIATE_CA_PATH/certs/$CLIENT_NAME.cert.pem"
