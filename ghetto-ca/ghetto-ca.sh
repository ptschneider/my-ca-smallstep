#!/bin/bash
# ghetto-ca: roll-your-own certificate authority
#            yes, it has been done a million times
# 2024NOV11: #1,000,001 by ptschne
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Background
# openssl configuration involves managing a flexible combination of command-line
# params and configuration file settings.
#
# ------------------------------------------------------------------------------
echo on
# ------------------------------------------------------------------------------
# initialize constants/defaults from file
GCA_CURR_HOME="$(pwd)" || fail "unable to pwd"
export GCA_CURR_HOME
GCA_FILE_GHETTO_CA_CONSTS="ghetto-ca.consts"
GCA_FILE_GHETTO_CA_CONSTS_PREV="${GCA_FILE_GHETTO_CA_CONSTS}.prev"
GCA_FILE_GHETTO_CA_VARS="ghetto-ca.vars"
GCA_FILE_GHETTO_CA_VARS_PREV="${GCA_FILE_GHETTO_CA_VARS}.prev"
set -a
# shellcheck disable=SC1090
source "${GCA_FILE_GHETTO_CA_CONSTS}" || fail "unable to retrieve settings"
# shellcheck disable=SC1090
source "${GCA_FILE_GHETTO_CA_VARS}" || fail "unable to retrieve settings"
export -a
GCA_NAME_ROOT_CA="${GCA_DEFAULT_NAME_ROOT_CA}"
GCA_NAME_SIGN_CA="${GCA_DEFAULT_NAME_SIGN_CA}"

# do not change it back with
# set +a
# ------------------------------------------------------------------------------
# openssl configuration fragments
#
cd "${GCA_CURR_HOME}" || fail "unable to cd to GCA_CURR_HOME [${GCA_CURR_HOME}]"
cat << EOF > "${GCA_FILE_ROOT_CA_REQ_BASE}"
[req]
default_bits            = 4096
encrypt_key             = yes
default_md              = sha256
utf8                    = yes
string_mask             = utf8only
prompt                  = no
EOF

cat << EOF > "${GCA_FILE_SIGN_CA_REQ_BASE}"
[req]
default_bits            = 2048
encrypt_key             = yes
default_md              = sha256
utf8                    = yes
string_mask             = utf8only
prompt                  = no
EOF

# for CSRs, apparently it makes no sense to have
# subjectKeyIdentifier   or  authorityKeyIdentifier
# lines at-all.
# they only make sense for CRTs apparently

cat << EOF > "${GCA_FILE_ROOT_CA_EXT_MIN_CFG}"
[ca_ext]
basicConstraints        = critical,CA:true
keyUsage                = critical,keyCertSign,cRLSign
EOF

cat << EOF > "${GCA_FILE_ROOT_CA_EXT}"
[ca_ext]
basicConstraints        = critical,CA:true
keyUsage                = critical,keyCertSign,cRLSign
subjectKeyIdentifier    = hash
EOF

cat << EOF > "${GCA_FILE_SIGN_CA_EXT}"
[sign_ca_ext]
authorityInfoAccess     = @issuer_info
authorityKeyIdentifier  = keyid:always
basicConstraints        = critical,CA:true,pathlen:0
crlDistributionPoints   = @crl_info
extendedKeyUsage        = clientAuth,serverAuth
keyUsage                = critical,keyCertSign,cRLSign
nameConstraints         = @name_constraints
subjectKeyIdentifier    = hash

[crl_info]
URI.0                   = $crl_url

[issuer_info]
caIssuers;URI.0         = $aia_url
OCSP;URI.0              = $ocsp_url

[name_constraints]
permitted;DNS.0=example.com
permitted;DNS.1=example.org
excluded;IP.0=0.0.0.0/0.0.0.0
excluded;IP.1=0:0:0:0:0:0:0:0/0:0:0:0:0:0:0:0
EOF

cat << EOF > "${GCA_FILE_OCSP_EXT}"
[ocsp_ext]
authorityKeyIdentifier  = keyid:always
basicConstraints        = critical,CA:false
extendedKeyUsage        = OCSPSigning
keyUsage                = critical,digitalSignature
subjectKeyIdentifier    = hash
EOF

# CRL extensions exist solely to point to the CA certificate that has issued the CRL.
cat << EOF > "${GCA_FILE_CRL_EXT}"
[ crl_ext ]
authorityKeyIdentifier  = keyid:always
EOF
# ------------------------------------------------------------------------------

function fail
{
   echo "ERROR: $1" >&2
   exit 1
}
# ------------------------------------------------------------------------------

function create_subtree
{
    local _gca_cadir="${1}"
    cd "${_gca_cadir}" || fail "unable to cd to ${_gca_cadir}"
    mkdir certs db private csr
    chmod 700 private
    touch db/index
    openssl rand -hex 16 > db/serial
    echo 1001 > db/crlnumber
    dd if=/dev/urandom of=private/random  bs=256 count=1
    echo "to see bytes written: xxd -p ${_gca_cadir}/private/random | tr -d '\n'"
}

# ------------------------------------------------------------------------------

function create_project_subtrees
{
    local _gca_parent="${1}"
    local _gca_projname="${2}"
    echo "create_project_subtrees ${_gca_parent} ${_gca_projname}"
    cd "${_gca_parent}" || fail "unable to cd to ${_gca_parent}"
    mkdir "${_gca_projname}"
    cd "${_gca_projname}" || fail "unable to cd to ${_gca_projname}"
    mkdir "${GCA_NAME_ROOT_CA}" "${GCA_NAME_SIGN_CA}"
    create_subtree "${_gca_parent}/${_gca_projname}/${GCA_NAME_ROOT_CA}"
    create_subtree "${_gca_parent}/${_gca_projname}/${GCA_NAME_SIGN_CA}"
}

# ------------------------------------------------------------------------------

function get_setup_params
{
  # prompt for new variable values, display current default, accept new value
	read -rp ":                         what 'country':[${GCA_DEFAULT_COUNTRY}] " GCA_COUNTRY
	read -rp ":                           what 'state':[${GCA_DEFAULT_STATE}] " GCA_STATE
	read -rp ":                        what 'locality':[${GCA_DEFAULT_LOCALITY}] " GCA_LOCALITY
	read -rp ":        name of sponsor org (mycompany):[${GCA_DEFAULT_SPONSOR}] " GCA_SPONSOR
	read -rp ":         the new system name (mysystem):[${GCA_DEFAULT_SYSTEM_NAME}] " GCA_SYSTEM_NAME
	read -rp ":              parent domain (myisp.com):[${GCA_DEFAULT_SPONSOR_DOMAIN}] " GCA_SPONSOR_DOMAIN
	read -rp ":         what's your desired passphrase:[${GCA_DEFAULT_PASSPHRASE}] " GCA_PASSPHRASE
  read -rp ":                AIA web server hostname:[${GCA_DEFAULT_HOSTNAME_AIA}] " GCA_HOSTNAME_AIA
  read -rp ":                CRL web server hostname:[${GCA_DEFAULT_HOSTNAME_CRL}] " GCA_HOSTNAME_CRL
  read -rp ":               OCSP web server hostname:[${GCA_DEFAULT_HOSTNAME_OCSP}] " GCA_HOSTNAME_OCSP
  read -rp ":                   OCSP web server port:[${GCA_DEFAULT_PORT_OCSP}] " GCA_PORT_OCSP

  # set the variables' final state; keep the default or update with new override
  GCA_COUNTRY="${GCA_COUNTRY:-${GCA_DEFAULT_COUNTRY}}"
  GCA_STATE="${GCA_STATE:-${GCA_DEFAULT_STATE}}"
  GCA_LOCALITY="${GCA_LOCALITY:-${GCA_DEFAULT_LOCALITY}}"
	GCA_SYSTEM_NAME="${GCA_SYSTEM_NAME:-${GCA_DEFAULT_SYSTEM_NAME}}"
	GCA_SPONSOR="${GCA_SPONSOR:-${GCA_DEFAULT_SPONSOR}}"
	GCA_SPONSOR_DOMAIN="${GCA_SPONSOR_DOMAIN:-${GCA_DEFAULT_SPONSOR_DOMAIN}}"
	GCA_PASSPHRASE="${GCA_PASSPHRASE:-${GCA_DEFAULT_PASSPHRASE}}"
	GCA_HOSTNAME_AIA="${GCA_HOSTNAME_AIA:-${GCA_DEFAULT_HOSTNAME_AIA}}"
	GCA_HOSTNAME_CRL="${GCA_HOSTNAME_CRL:-${GCA_DEFAULT_HOSTNAME_CRL}}"
	GCA_HOSTNAME_OCSP="${GCA_HOSTNAME_OCSP:-${GCA_DEFAULT_HOSTNAME_OCSP}}"
	GCA_PORT_OCSP="${GCA_PORT_OCSP:-${GCA_DEFAULT_PORT_OCSP}}"

  # copy final state of variables back into the defaults
  GCA_DEFAULT_COUNTRY="${GCA_COUNTRY}"
  GCA_DEFAULT_STATE="${GCA_STATE}"
  GCA_DEFAULT_LOCALITY="${GCA_LOCALITY}"
	GCA_DEFAULT_SYSTEM_NAME="${GCA_SYSTEM_NAME}"
	GCA_DEFAULT_SPONSOR="${GCA_SPONSOR}"
  GCA_DEFAULT_SPONSOR_DOMAIN="${GCA_SPONSOR_DOMAIN}"
  GCA_DEFAULT_PASSPHRASE="${GCA_PASSPHRASE}"
  GCA_DEFAULT_HOSTNAME_AIA="${GCA_HOSTNAME_AIA}"
  GCA_DEFAULT_HOSTNAME_CRL="${GCA_HOSTNAME_CRL}"
  GCA_DEFAULT_HOSTNAME_OCSP="${GCA_HOSTNAME_OCSP}"
  GCA_DEFAULT_PORT_OCSP="${GCA_PORT_OCSP}"
}
# ------------------------------------------------------------------------------
function create_root_ca_csr
{
  echo -n "create root ca csr..."

  # shellcheck disable=SC2206
  sd_arr=(${GCA_SPONSOR_DOMAIN//./ })

  echo "GCA_CURR_HOME: [${GCA_CURR_HOME}"
  cd "${GCA_CURR_HOME}" || fail "unable to cd to GCA_CURR_HOME [${GCA_CURR_HOME}]"

  GCA_CN_ROOT_CA="${GCA_SYSTEM_NAME} ${GCA_NAME_ROOT_CA} 2024"

cat << EOF > "${GCA_FILE_ROOT_CA_CSR_CFG_HDR}"
[default]
default_ca=ca_default
name_opt=utf8,esc_ctrl,multiline,lname,align
EOF

cat << EOF > "${GCA_FILE_ROOT_CA_DN_CSR_CFG}"
distinguished_name      = ca_dn
req_extensions          = ca_ext
[ca_dn]
0.domainComponent       = ${sd_arr[1]}
1.domainComponent       = ${sd_arr[0]}
countryName             = ${GCA_COUNTRY}
organizationName        = ${GCA_SPONSOR}
commonName              = ${GCA_CN_ROOT_CA}
stateOrProvinceName     = ${GCA_STATE}
localityName            = ${GCA_LOCALITY}
organizationalUnitName  = ${GCA_SYSTEM_NAME}
emailAddress            = admin@${GCA_SYSTEM_NAME}.${GCA_SPONSOR_DOMAIN}
EOF

#  echo "cat ${GCA_FILE_ROOT_CA_CSR_CFG_HDR} > ${GCA_FILE_ROOT_CA_CSR_CFG}"
#  echo "cat ${GCA_FILE_CA_REQ_BASE} >> ${GCA_FILE_ROOT_CA_CSR_CFG}"
#  echo "cat ${GCA_FILE_ROOT_CA_DN_CSR_CFG} >> ${GCA_FILE_ROOT_CA_CSR_CFG}"
#  echo "cat ${GCA_FILE_ROOT_CA_EXT} >> ${GCA_FILE_ROOT_CA_CSR_CFG}"

  cat "${GCA_FILE_ROOT_CA_CSR_CFG_HDR}" > "${GCA_FILE_ROOT_CA_CSR_CFG}"
  cat "${GCA_FILE_ROOT_CA_REQ_BASE}" >> "${GCA_FILE_ROOT_CA_CSR_CFG}"
  cat "${GCA_FILE_ROOT_CA_DN_CSR_CFG}" >> "${GCA_FILE_ROOT_CA_CSR_CFG}"
  cat "${GCA_FILE_ROOT_CA_EXT_MIN_CFG}" >> "${GCA_FILE_ROOT_CA_CSR_CFG}"

#  echo "openssl req"
#  echo "-config ${GCA_FILE_ROOT_CA_CSR_CFG}"
#  echo "-verbose"
#  echo "-new"
#  echo "-out ${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/csr/${GCA_NAME_ROOT_CA}.csr.pem"
#  echo "-keyout ${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_NAME_ROOT_CA}.key.pem"
#  echo "-passout file:${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_FILE_PASSPHRASE_A}"

  openssl req \
    -config "${GCA_FILE_ROOT_CA_CSR_CFG}" \
    -verbose \
    -new \
    -out "${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/csr/${GCA_NAME_ROOT_CA}.csr.pem" \
    -keyout "${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_NAME_ROOT_CA}.key.pem" \
    -passout file:"${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_FILE_PASSPHRASE_A}"

  echo "done."
}
# ------------------------------------------------------------------------------

function create_root_ca_crt
{
  echo -n "create root ca crt..."

  cd "${GCA_CURR_HOME}" || fail "unable to cd to GCA_CURR_HOME [${GCA_CURR_HOME}]"

cat << EOF > "${GCA_FILE_ROOT_CA_CRT_CFG_HDR}"
[default]
default_ca=ca_default
name_opt=utf8,esc_ctrl,multiline,lname,align
[ca_default]
home                    = ${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}
database                = ${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/db/index
serial                  = ${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/db/serial
crlnumber               = ${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/db/crlnumber
certificate             = ${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/certs/${GCA_NAME_ROOT_CA}.crt.pem
private_key             = ${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_NAME_ROOT_CA}.key.pem
RANDFILE                = ${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/random
new_certs_dir           = ${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/certs
unique_subject          = no
copy_extensions         = none
default_days            = 3650
default_crl_days        = 365
default_md              = sha256
policy                  = policy_supplied
[policy_supplied]
countryName             = supplied
stateOrProvinceName     = supplied
organizationName        = supplied
organizationalUnitName  = supplied
commonName              = supplied
domainComponent         = supplied
localityName            = supplied
emailAddress            = supplied
EOF

# first 1 or 2 statements may only be needed for CSR creation
  cat "${GCA_FILE_ROOT_CA_CRT_CFG_HDR}" > "${GCA_FILE_ROOT_CA_CRT_CFG}"
  cat "${GCA_FILE_ROOT_CA_REQ_BASE}" >> "${GCA_FILE_ROOT_CA_CRT_CFG}"
  cat "${GCA_FILE_ROOT_CA_DN_CSR_CFG}" >> "${GCA_FILE_ROOT_CA_CRT_CFG}"
  cat "${GCA_FILE_ROOT_CA_EXT}" >> "${GCA_FILE_ROOT_CA_CRT_CFG}"

  openssl ca \
    -config "${GCA_FILE_ROOT_CA_CRT_CFG}" \
    -verbose \
    -selfsign \
    -in "${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/csr/${GCA_NAME_ROOT_CA}.csr.pem" \
    -batch \
    -out "${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/certs/${GCA_NAME_ROOT_CA}.crt.pem" \
    -extensions ca_ext \
    -passin file:"${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_FILE_PASSPHRASE_A}"

  echo "done."
}
# ------------------------------------------------------------------------------

function create_root_ca_crl
{
  echo -n "create root ca crl..."
  # crl is also PEM format, yes?
  openssl ca \
    -config "${GCA_FILE_ROOT_CA_CRT_CFG}" \
    -verbose \
    -gencrl \
    -out "${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/${GCA_NAME_ROOT_CA}.crl" \
    -passin file:"${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_FILE_PASSPHRASE_A}"
  #	-copy_extensions none \
  echo "done."
}
# ------------------------------------------------------------------------------

function create_root_ocsp_csr
{
  echo -n "create root ocsp csr..."
  # should extract this string from output of previous commands
  # yet brute force rules where grace wilts
  # this is displayed when the root-ca CRL is generated (previous step)
  HARDCODED_DN="/C=us/ST=az/O=azgt/OU=avidbison/CN=avidbison root-ca 2024/DC=coop/DC=azgt/L=development/emailAddress=admin@avidbison.azgt.coop"
  # instructions said not to specify a config (but then it uses the system default which doesn't seem right either)
  openssl req -verbose \
    -new \
    -newkey rsa:2048 \
    -subj "${HARDCODED_DN}" \
    -addext "subjectAltName=DNS:ocsp.${GCA_SYSTEM_NAME}.${GCA_SPONSOR_DOMAIN},DNS:${GCA_SYSTEM_NAME}.${GCA_SPONSOR_DOMAIN}" \
    -copy_extensions copyall \
    -keyout "${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/root-ocsp.key.pem" \
    -out "${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/csr/root-ocsp.csr.pem" \
    -passout file:"${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_FILE_PASSPHRASE_A}"
  echo "done."
}
# ------------------------------------------------------------------------------

function create_root_ocsp_crt
{
  echo -n "create root ocsp crt..."

  cat "${GCA_FILE_ROOT_CA_CRT_CFG}" > "${GCA_FILE_ROOT_CA_OCSP_CFG}"
  cat "${GCA_FILE_OCSP_EXT}" >> "${GCA_FILE_ROOT_CA_OCSP_CFG}"

  openssl ca \
    -config "${GCA_FILE_ROOT_CA_OCSP_CFG}" \
    -verbose \
    -in "${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/csr/root-ocsp.csr.pem" \
    -batch \
    -out "${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/certs/root-ocsp.crt.pem" \
    -extensions ocsp_ext \
    -days 30 \
    -passin file:"${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_FILE_PASSPHRASE_A}"

  echo "done."
}
# ------------------------------------------------------------------------------

function create_sign_ca_csr
{
  echo -n "create sign-ca CSR..."

    # shellcheck disable=SC2206
    sd_arr=(${GCA_SPONSOR_DOMAIN//./ })

    cd "${GCA_CURR_HOME}" || fail "unable to cd to GCA_CURR_HOME [${GCA_CURR_HOME}]"

    GCA_CN_SIGN_CA="${GCA_SYSTEM_NAME} ${GCA_NAME_SIGN_CA} 2024"

cat << EOF > "${GCA_FILE_SIGN_CA_DN_CSR_CFG}"
distinguished_name      = sign_ca_dn
req_extensions          = ca_ext
[sign_ca_dn]
0.domainComponent       = ${sd_arr[1]}
1.domainComponent       = ${sd_arr[0]}
countryName             = ${GCA_COUNTRY}
organizationName        = ${GCA_SPONSOR}
commonName              = ${GCA_CN_SIGN_CA}
stateOrProvinceName     = ${GCA_STATE}
localityName            = ${GCA_LOCALITY}
organizationalUnitName  = ${GCA_SYSTEM_NAME}
emailAddress            = admin@${GCA_SYSTEM_NAME}.${GCA_SPONSOR_DOMAIN}
EOF

  cat "${GCA_FILE_ROOT_CA_CSR_CFG_HDR}" > "${GCA_FILE_SIGN_CA_CSR_CFG}"
  cat "${GCA_FILE_ROOT_CA_REQ_BASE}" >> "${GCA_FILE_SIGN_CA_CSR_CFG}"
  cat "${GCA_FILE_SIGN_CA_DN_CSR_CFG}" >> "${GCA_FILE_SIGN_CA_CSR_CFG}"
  cat "${GCA_FILE_ROOT_CA_EXT_MIN_CFG}" >> "${GCA_FILE_SIGN_CA_CSR_CFG}"

  openssl req \
    -config "${GCA_FILE_SIGN_CA_CSR_CFG}" \
    -verbose \
    -new \
    -out "${GCA_SYSTEM_NAME}/${GCA_NAME_SIGN_CA}/csr/${GCA_NAME_SIGN_CA}.csr.pem" \
    -keyout "${GCA_SYSTEM_NAME}/${GCA_NAME_SIGN_CA}/private/${GCA_NAME_SIGN_CA}.key.pem" \
    -passout file:"${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_FILE_PASSPHRASE_A}"

  echo "done."
}
# ------------------------------------------------------------------------------

function create_sign_ca_crt
{
  echo -n "create sign-ca cert..."

  # ${GCA_FILE_SIGN_CA_CRT_CFG}
#    cat "${GCA_FILE_ROOT_CA_CRT_CFG_HDR}" > "${GCA_FILE_ROOT_CA_CRT_CFG}"
#    cat "${GCA_FILE_CA_REQ_BASE}" >> "${GCA_FILE_ROOT_CA_CRT_CFG}"
#    cat "${GCA_FILE_ROOT_CA_DN_CSR_CFG}" >> "${GCA_FILE_ROOT_CA_DN_CSR_CFG}"
#    cat "${GCA_FILE_ROOT_CA_EXT}" >> "${GCA_FILE_ROOT_CA_CRT_CFG}"

  cat "${GCA_FILE_ROOT_CA_CRT_CFG_HDR}" > "${GCA_FILE_SIGN_CA_CRT_CFG}"
  cat "${GCA_FILE_ROOT_CA_REQ_BASE}" >> "${GCA_FILE_SIGN_CA_CRT_CFG}"
  cat "${GCA_FILE_SIGN_CA_DN_CSR_CFG}" >> "${GCA_FILE_SIGN_CA_CRT_CFG}"
  cat "${GCA_FILE_SIGN_CA_EXT}" >> "${GCA_FILE_SIGN_CA_CRT_CFG}"

  openssl ca \
    -config "${GCA_FILE_SIGN_CA_CRT_CFG}" \
    -verbose \
    -in "${GCA_SYSTEM_NAME}/${GCA_NAME_SIGN_CA}/csr/${GCA_NAME_SIGN_CA}.csr.pem" \
    -batch \
    -out "${GCA_SYSTEM_NAME}/${GCA_NAME_SIGN_CA}/certs/${GCA_NAME_SIGN_CA}.crt.pem" \
    -extensions sign_ca_ext \
    -passin file:"${GCA_SYSTEM_NAME}/${GCA_NAME_ROOT_CA}/private/${GCA_FILE_PASSPHRASE_A}"

  echo "done."
}
# ------------------------------------------------------------------------------
function setup_new_ca_directories
{
    echo ":              create new cert authority:"
    cd "${GCA_CURR_HOME}" || fail "unable to cd to GCA_CURR_HOME ${GCA_CURR_HOME}"
    get_setup_params
    echo "setup_new_ca [${GCA_CURR_HOME}] [${GCA_SYSTEM_NAME}]"
    create_project_subtrees "${GCA_CURR_HOME}" "${GCA_SYSTEM_NAME}"

    GCA_DIR_PROJ="${GCA_CURR_HOME}/${GCA_SYSTEM_NAME}"
    GCA_DIR_ROOT_CA="${GCA_DIR_PROJ}/${GCA_NAME_ROOT_CA}"
    GCA_DIR_SIGN_CA="${GCA_DIR_PROJ}/${GCA_NAME_SIGN_CA}"
    echo "${GCA_PASSPHRASE}" > "${GCA_DIR_ROOT_CA}/private/${GCA_FILE_PASSPHRASE_A}"
    echo "${GCA_PASSPHRASE}" > "${GCA_DIR_ROOT_CA}/private/${GCA_FILE_PASSPHRASE_B}"
}
# ------------------------------------------------------------------------------

function save_settings
{
    echo "saving settings for next time..."
    cd "${GCA_CURR_HOME}" || fail "unable to cd to GCA_CURR_HOME ${GCA_CURR_HOME}"

    rm -f "${GCA_FILE_GHETTO_CA_VARS_PREV}"
    mv "${GCA_FILE_GHETTO_CA_VARS}" "${GCA_FILE_GHETTO_CA_VARS_PREV}"
    echo "# ${GCA_FILE_GHETTO_CA_VARS}" > "${GCA_FILE_GHETTO_CA_VARS}"
    echo "# WARNING: this file auto-generated; values can be changed but not keys" >> "${GCA_FILE_GHETTO_CA_VARS}"
    # printenv | grep '^GCA_' >> "${GCA_FILE_GHETTO_CA_VARS}"
    set -o posix
    export -p | grep '^export GCA_' | grep '^export GCA_DEFAULT_' >> "${GCA_FILE_GHETTO_CA_VARS}"

    rm -f "${GCA_FILE_GHETTO_CA_CONSTS_PREV}"
    mv "${GCA_FILE_GHETTO_CA_CONSTS}" "${GCA_FILE_GHETTO_CA_CONSTS_PREV}"
    echo "# ${GCA_FILE_GHETTO_CA_CONSTS}" > "${GCA_FILE_GHETTO_CA_CONSTS}"
    echo "# WARNING: this file auto-generated; values can be changed but not keys" >> "${GCA_FILE_GHETTO_CA_CONSTS}"
    export -p | grep '^export GCA_' | grep '^export GCA_FILE_' >> "${GCA_FILE_GHETTO_CA_CONSTS}"
}
# ------------------------------------------------------------------------------

function cleanup_tmpfiles
{
    echo "cleanup tmpfiles..."
    cd "${GCA_CURR_HOME}" || fail "unable to cd to GCA_CURR_HOME ${GCA_CURR_HOME}"
    rm -f "gcp_*"
}
# ------------------------------------------------------------------------------

function display_usage_message
{
  echo
  echo ":                                  Usage: ghetto-ca create"
  echo ":              creates a new two-tier CA:"
}
# ------------------------------------------------------------------------------
# main()

if [ "$1" = "create" ]     # Request help.
then
  echo ":                              ghetto-ca:"
  setup_new_ca_directories
  create_root_ca_csr
  create_root_ca_crt
  create_root_ca_crl
  create_root_ocsp_csr
  create_root_ocsp_crt
  create_sign_ca_csr
  create_sign_ca_crt
  save_settings
#  cleanup_tmpfiles
else
  display_usage_message
fi

echo ":                              thank you:"
echo

# ------------------------------------------------------------------------------


