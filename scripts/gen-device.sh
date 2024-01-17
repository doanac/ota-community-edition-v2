#!/bin/bash

set -euo pipefail

DEVICE_UUID=${DEVICE_UUID:-$(uuidgen | tr "[:upper:]" "[:lower:]")}
CWD=$(dirname "$0")
SERVER_DIR=$CWD/../ota-ce-gen
DEVICES_DIR=${SERVER_DIR}/devices

GATEWAY=$(openssl x509 -in  $SERVER_DIR/server.crt -noout -ext subjectAltName  | grep DNS: | cut -d: -f2)

device_id=$DEVICE_UUID
device_dir="${DEVICES_DIR}/${DEVICE_UUID}"

mkdir -p "${device_dir}"

echo "Gateway URL is: $GATEWAY"

openssl ecparam -genkey -name prime256v1 | openssl ec -out "${device_dir}/pkey.ec.pem"
openssl pkcs8 -topk8 -nocrypt -in "${device_dir}/pkey.ec.pem" -out "${device_dir}/pkey.pem"

openssl req -new -key "${device_dir}/pkey.pem" \
          -config <(sed "s/\$ENV::DEVICE_UUID/${DEVICE_UUID}/g" "${CWD}/certs/client.cnf") \
          -out "${device_dir}/${device_id}.csr"

openssl x509 -req -days 365 -extfile "${CWD}/certs/client.ext" -in "${device_dir}/${device_id}.csr" \
        -CAkey "${DEVICES_DIR}/ca.key" -CA "${DEVICES_DIR}/ca.crt" -CAcreateserial -out "${device_dir}/client.pem"

cat "${device_dir}/client.pem" "${DEVICES_DIR}/ca.crt" > "${device_dir}/${device_id}.chain.pem"

server_ca=$(realpath ${SERVER_DIR}/server_ca.pem)
ln -s "${server_ca}" "${device_dir}/ca.pem" || true

openssl x509 -in "${device_dir}/client.pem" -text -noout

credentials="$(cat ${DEVICES_DIR}/${DEVICE_UUID}/client.pem | sed -z -r -e 's@\n@\\n@g')"

body=$(cat <<END
{"credentials":"${credentials}","deviceId":"${device_id}","deviceName":"${device_id}","deviceType":"Other","uuid":"${DEVICE_UUID}"}
END
    )

cat > ${device_dir}/sota.toml <<EOF
[provision]
primary_ecu_hardware_id = "intel-corei7-64"

[tls]
server = "https://${GATEWAY}:30443"

[logger]
loglevel = 1

[storage]
path = "/var/sota-uptane"

[pacman]
type = "ostree"
ostree_sever = "https://${GATEWAY}:30443/treehub"

[uptane]
key_source = "file"
repo_server = "https://${GATEWAY}:30443/repo"
director_server = "https://${GATEWAY}:30443/director"
polling_sec = 30

[import]
base_path = "/var/sota-uptane"
tls_cacert_path = "ca.pem"
tls_clientcert_path = "client.pem"
tls_pkey_path = "pkey.pem"
EOF

curl -X PUT -d "${body}" http://deviceregistry.${GATEWAY}/api/v1/devices -s -S -v -H "Content-Type: application/json" -H "Accept: application/json, */*"