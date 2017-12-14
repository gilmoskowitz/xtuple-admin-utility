# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

generate_p12() {
WORKDATE=$(date "+%m%d%y")

# THE P12 KEY OUT NEEDS TO GO IN /var/xtuple/keys/
NGINX_ECOM_DOMAIN='xTupleCommerce'
ECOMM_ADMIN_EMAIL="admin@xtuple.xd"
ERP_SITE_URL='xtuple.xd'
WORKDIR=${BUILD_WORKING}
KEY_P12_PATH=${BUILD_WORKING}/private
KEYTMP=${KEY_P12_PATH}/tmp_${WORKDATE}
mkdir -p ${KEY_P12_PATH}
mkdir -p ${KEYTMP}

NGINX_ECOM_DOMAIN_P12=${NGINX_ECOM_DOMAIN}.p12

ssh-keygen -t rsa -b 2048 -C "${ECOMM_ADMIN_EMAIL}" -f ${KEYTMP}/keypair.key -P ''
openssl req -batch -new -key ${KEYTMP}/keypair.key -out ${KEYTMP}/keypair.csr
openssl x509 -req -in ${KEYTMP}/keypair.csr -signkey ${KEYTMP}/keypair.key -out ${KEYTMP}/keypair.crt
openssl pkcs12 -export -in ${KEYTMP}/keypair.crt -inkey ${KEYTMP}/keypair.key -out ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -password pass:notasecret
openssl pkcs12 -in ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -passin pass:notasecret -nocerts -nodes | openssl rsa > ${KEYTMP}/private.pem
openssl rsa -in ${KEYTMP}/private.pem -passin pass:notasecret -pubout -passout pass:notasecret > ${KEYTMP}/public.pem
cp ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} ${KEY_P12_PATH}

OAPUBKEY=$(<${KEYTMP}/public.pem)
export OAPUBKEY=${OAPUBKEY}
echo "Created OAPUBKEY"
}


generateoasql()
{
cat << EOF >> ${WORKDIR}/sql/oa2client.sql
UPDATE xt.oa2client SET oa2client_client_id='xTupleCommerceSite_${WORKDATE}' WHERE oa2client_client_id='xTupleCommerceSite' AND oa2client_client_x509_pub_cert != '${OAPUBKEY}';

INSERT INTO xt.oa2client(oa2client_client_id, oa2client_client_secret, oa2client_client_name, \
oa2client_client_email, oa2client_client_web_site, oa2client_client_type, oa2client_active, \
oa2client_issued, oa2client_delegated_access, oa2client_client_x509_pub_cert, oa2client_org) \
SELECT 'xTupleCommerceSite' AS oa2client_client_id, xt.uuid_generate_v4() AS oa2client_client_secret, \
'${NGINX_ECOM_DOMAIN}' AS oa2client_client_name, '${ECOMM_ADMIN_EMAIL}' AS oa2client_client_email, \
'${ERP_SITE_URL}' AS oa2client_client_web_site, 'jwt bearer' AS oa2client_client_type, TRUE AS oa2client_active,  \
now() AS oa2client_issued , TRUE AS oa2client_delegated_access, '${OAPUBKEY}' AS oa2client_client_x509_pub_cert, current_database()
AS  oa2client_org
WHERE NOT EXISTS ( SELECT 1 FROM xt.oa2client WHERE oa2client_client_x509_pub_cert='${OAPUBKEY}');
EOF

}


