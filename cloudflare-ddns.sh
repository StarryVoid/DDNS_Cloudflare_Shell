#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#
# Dynamic Domain Name Server (Cloudflare API)
#
# Author: StarryVoid <stars@starryvoid.com>
# Intro:  https://blog.starryvoid.com/archives/313.html
# Build:  2021/05/06 Version 2.3.2.3
#

# Select API(1) Or Token(2)
SelectAT="2"

# CloudFlare API " X-Auth-Email: *** " " X-Auth-Key: *** "
XAUTHEMAIL="YOUREMAILADDRESS"
XAUTHKEY="YOURCLOUDFLAREAPIKEY"

# CloudFlare Token " Authorization: Bearer *** "
AuthorizationToken="YOURTOKEN"

# Domain Name " example.domain " " ddns.example.domain "
ZONENAME="example.domain"
DOMAINNAME="ddns.example.domain"
DOMAINTTL="1"

# Output
OUTPUTLOG="$(pwd)/${DOMAINNAME}.log"
OUTPUTINFO="/tmp/ddns_${DOMAINNAME}.info"

# Time
DATETIME=$(date +%Y%m%d_%H%M%S)

# ------------ Start ------------

function check_file_directory() {
  if [ "$(pwd)" == "/" ]; then
    if [ -f "${OUTPUTLOG}" ]; then
      echo "[Warning] The current directory is \"""$(pwd)""\". Please move to another path and delete this log file." > "${OUTPUTLOG}" ; exit 1
    else
      if ! [ -f "$(pwd)/ddns_readme.log" ]; then echo "[Warning] The current directory is \"""$(pwd)""\". For management reasons, the log file path has been moved to \"/var/log/ddns/\". Remember to delete the log file similar to \"ddns.example.domain.log\" in the \"/\" directory." > "$(pwd)"./ddns_readme.log ; fi
      OUTPUTLOG="/var/log/ddns/${DOMAINNAME}.log"
      if ! [ -d "/var/log/ddns/" ]; then mkdir "/var/log/ddns/" && touch "${OUTPUTLOG}" ; fi
      if ! [ -f "${OUTPUTLOG}" ]; then echo "[Error] Could not create log file \"""${OUTPUTLOG}""\"" ; exit 1 ; fi
    fi
  fi 
}

function make_log() {
    echo "[$1][$(date +%Y%m%d_%H%M%S)] $2" >> "${OUTPUTLOG}" 
}

function check_environment () {
  if ! [ "$(command -v pwd)" ]; then make_log Error "Command not found \"pwd\"" ; exit 1 ; fi
  if ! [ -x "$(command -v curl)" ]; then make_log Error "Command not found \"curl\"" ; exit 1 ; fi
}

function check_selectAT () {
  if [[ ! "${SelectAT}" = 1 && ! "${SelectAT}" = 2 ]]; then make_log Error "Failed to Select API(1) Or Token(2), Please check the configuration." ; exit 1; fi
}

function check_ipaddress() {
  CHECKIPADD=$(echo "$1" | head -n 1)
  if echo "${CHECKIPADD}" | grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" > /dev/null ; then   
      echo "${CHECKIPADD}" | awk -F "." '$1<=255&&$2<=255&&$3<=255&&$4<=255{print $1"."$2"."$3"."$4}'
  else   
      echo ""   
  fi
}

function cloudflare_return_log_check() {
  cloudflare_return_log_check_status=$(echo "$1" | awk BEGIN"{RS=EOF}"'{gsub(/,/,"\n");print}' | sed 's/{/\n{\n/g' | sed 's/}/\n}\n/g' | sed 's/ //g' | grep -v "^$" | grep "$2" | head -1 | awk -F ":" '{print $2}' | sed 's/\"//g' )
  echo "${cloudflare_return_log_check_status}" 
}

function get_cloudflare_ipaddress_api() {
  [ -z "${Data_zone_records}" ] && LOG_get_zone_records_api=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$1" -H "X-Auth-Email: ${XAUTHEMAIL}" -H "X-Auth-Key: ${XAUTHKEY}" -H "Content-Type: application/json" --connect-timeout 30 -m 10 )
  [ -z "${Data_zone_records}" ] && if [ ! "$(cloudflare_return_log_check "${LOG_get_zone_records_api}" "success")" == "true" ]; then make_log Error "Failed to get cloudflare \"$1\" zone_records information" ; exit 1; fi
  [ -z "${Data_zone_records}" ] && Data_zone_records=$(cloudflare_return_log_check "${LOG_get_zone_records_api}" "id")
  [ -z "${Data_dns_records}" ] && LOG_get_dns_records_api=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${Data_zone_records}/dns_records?type=A&name=$2" -H "X-Auth-Email: ${XAUTHEMAIL}" -H "X-Auth-Key: ${XAUTHKEY}" -H "Content-Type: application/json" --connect-timeout 30 -m 10 )
  [ -z "${Data_dns_records}" ] && if [ ! "$(cloudflare_return_log_check "${LOG_get_dns_records_api}" "success")" == "true" ]; then make_log Error "Failed to get cloudflare \"$2\" dns_records information" ; exit 1; fi
  [ -z "${Data_dns_records}" ] && Data_dns_records=$(cloudflare_return_log_check "${LOG_get_dns_records_api}" "id")
  LOG_get_domain_ip_api=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${Data_zone_records}/dns_records/${Data_dns_records}" -H "X-Auth-Email: ${XAUTHEMAIL}" -H "X-Auth-Key: ${XAUTHKEY}" -H "Content-Type: application/json" --connect-timeout 30 -m 10 )
  if [ ! "$(cloudflare_return_log_check "${LOG_get_domain_ip_api}" "success")" == "true" ]; then make_log Error "Failed to get cloudflare \"$2\" ip_address information" ; exit 1; fi
  Data_domain_ip=$(cloudflare_return_log_check "${LOG_get_domain_ip_api}" content)
}

function get_cloudflare_ipaddress_token() {
  [ -z "${Data_zone_records}" ] && LOG_get_zone_records_token=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$1" -H "Authorization: Bearer ${AuthorizationToken}" -H "Content-Type: application/json" --connect-timeout 30 -m 10 )
  [ -z "${Data_zone_records}" ] && if [ ! "$(cloudflare_return_log_check "${LOG_get_zone_records_token}" "success")" == "true" ]; then make_log Error "Failed to get cloudflare \"$1\" zone_records information" ; exit 1; fi
  [ -z "${Data_zone_records}" ] && Data_zone_records=$(cloudflare_return_log_check "${LOG_get_zone_records_token}" "id")
  [ -z "${Data_dns_records}" ] && LOG_get_dns_records_token=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${Data_zone_records}/dns_records?type=A&name=$2" -H "Authorization: Bearer ${AuthorizationToken}" -H "Content-Type: application/json" --connect-timeout 30 -m 10 )
  [ -z "${Data_dns_records}" ] && if [ ! "$(cloudflare_return_log_check "${LOG_get_dns_records_token}" "success")" == "true" ]; then make_log Error "Failed to get cloudflare \"$2\" dns_records information" ; exit 1; fi
  [ -z "${Data_dns_records}" ] && Data_dns_records=$(cloudflare_return_log_check "${LOG_get_dns_records_token}" "id")
  LOG_get_domain_ip_token=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${Data_zone_records}/dns_records/${Data_dns_records}" -H "Authorization: Bearer ${AuthorizationToken}" -H "Content-Type: application/json" --connect-timeout 30 -m 10 )
  if [ ! "$(cloudflare_return_log_check "${LOG_get_domain_ip_token}" "success")" == "true" ]; then make_log Error "Failed to get cloudflare \"$2\" ip_address information" ; exit 1; fi
  Data_domain_ip=$(cloudflare_return_log_check "${LOG_get_domain_ip_token}" content)
}

function get_server_new_ip() {
  [ -z "${NEWIPADD}" ] && NEWIPADD=$( check_ipaddress "$(curl -s --retry 1 --connect-timeout 1 https://api.ipify.org/)" )
  [ -z "${NEWIPADD}" ] && NEWIPADD=$( check_ipaddress "$(curl -s --retry 1 --connect-timeout 1 https://ipinfo.io/ip/)" )
  [ -z "${NEWIPADD}" ] && NEWIPADD=$( check_ipaddress "$(curl -s --retry 1 --connect-timeout 1 http://api.ipify.org/)" )
  [ -z "${NEWIPADD}" ] && NEWIPADD=$( check_ipaddress "$(curl -s --retry 1 --connect-timeout 1 http://ipinfo.io/ip/)" )
    [ -z "${NEWIPADD}" ] && NEWIPADD=$( check_ipaddress "$(curl -s --retry 0 --connect-timeout 10 http://ip-api.com/line/?fields=query)" )
  if [[ ! "${NEWIPADD}" ]]; then make_log Error "Failed to obtain the public address of the current network." ; exit 1; fi
}

function update_new_ipaddress_api() {
  make_log Info "IP address will been modified from \"""${Data_domain_ip}""\" to \"""${NEWIPADD}""\"."
  LOG_update_new_ipaddress_api=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${Data_zone_records}/dns_records/${Data_dns_records}" -H "X-Auth-Email: ${XAUTHEMAIL}" -H "X-Auth-Key: ${XAUTHKEY}" -H "Content-Type: application/json"  --data "{\"type\":\"A\",\"name\":\"""$1""\",\"content\":\"""$2""\",\"ttl\":""$3"",\"proxied\":false}" --connect-timeout 30 -m 10 )
  if [ ! "$(cloudflare_return_log_check "${LOG_update_new_ipaddress_api}" "success")" == "true" ]; then make_log Error "Failed to update cloudflare address." ; exit 1; fi
}

function update_new_ipaddress_token() {
  make_log Info "IP address will been modified from \"""${Data_domain_ip}""\" to \"""${NEWIPADD}""\"."
  LOG_update_new_ipaddress_token=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${Data_zone_records}/dns_records/${Data_dns_records}" -H "Authorization: Bearer ${AuthorizationToken}" -H "Content-Type: application/json"  --data "{\"type\":\"A\",\"name\":\"""$1""\",\"content\":\"""$2""\",\"ttl\":""$3"",\"proxied\":false}" --connect-timeout 30 -m 10 )
  if [ ! "$(cloudflare_return_log_check "${LOG_update_new_ipaddress_token}" "success")" == "true" ]; then make_log Error "Failed to update cloudflare address." ; exit 1; fi
}


function update_new_ipaddress() {
  if [ "${SelectAT}" = 1 ]; then update_new_ipaddress_api "${DOMAINNAME}" "${NEWIPADD}" "${DOMAINTTL}" ; fi
  if [ "${SelectAT}" = 2 ]; then update_new_ipaddress_token "${DOMAINNAME}" "${NEWIPADD}" "${DOMAINTTL}" ; fi
  sleep 10s
  if [[ ! "${Data_domain_ip}" ]]; then Data_domain_ip="" ; fi
  if [ "${SelectAT}" = 1 ]; then get_cloudflare_ipaddress_api "${ZONENAME}" "${DOMAINNAME}" ; fi
  if [ "${SelectAT}" = 2 ]; then get_cloudflare_ipaddress_token "${ZONENAME}" "${DOMAINNAME}" ; fi
  if [[ "${NEWIPADD}" == "${Data_domain_ip}" ]]; then
    make_log Info "IP address has been modified to \"""${NEWIPADD}""\"."
    make_records_file
    exit 0
  else
    make_log Error "IP address modification failed."
    exit 1
  fi
}

function make_records_file() {
  echo "{\"datatime\":""${DATETIME}"",\"zone_records\":""${Data_zone_records}"",\"dns_records\":""${Data_dns_records}"",\"ip_address\":""${NEWIPADD}""}" > "${OUTPUTINFO}"
  make_log Info "Successfully generated DDNS information file."
}

function read_records_file() {
  if [ -f "${OUTPUTINFO}" ]; then 
    Data_file_info=$(cat < "${OUTPUTINFO}")
    Data_zone_records=$(cloudflare_return_log_check "${Data_file_info}" zone_records)
    Data_dns_records=$(cloudflare_return_log_check "${Data_file_info}" dns_records)
    Old_domain_ip=$(cloudflare_return_log_check "${Data_file_info}" ip_address)
  else
    make_log Alert "Could not find local configuration file."
  fi
  if ! [[ "${Data_zone_records}" && "${Data_dns_records}" && "${Old_domain_ip}" ]]; then make_log Alert "Failed to check local configuration file." ; fi
}

function main() {
  check_file_directory
  check_environment
  check_selectAT
#  make_log Info "Running Time is ${DATETIME}"
  get_server_new_ip
  read_records_file
  if [[ "${NEWIPADD}" != "${Old_domain_ip}" ]]; then
    if [ "${SelectAT}" = 1 ]; then get_cloudflare_ipaddress_api "${ZONENAME}" "${DOMAINNAME}" ; fi
    if [ "${SelectAT}" = 2 ]; then get_cloudflare_ipaddress_token "${ZONENAME}" "${DOMAINNAME}" ; fi
    if [[ "${NEWIPADD}" != "${Data_domain_ip}" ]]; then
      update_new_ipaddress
      exit 0
    else
#    make_log Info "The ip address is the same as the cloudflare record."
      make_records_file
      exit 0
    fi
  else 
#    make_log Info "There is no need to change ip address."
    exit 0
  fi
}

main
