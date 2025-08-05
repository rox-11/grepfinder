#!/bin/bash

# Colors for output
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color

# Extended keyword groups for bug bounty reconnaissance
declare -A KEYWORD_GROUPS

KEYWORD_GROUPS["tokens"]="token|apikey|bearer|jwt|session|auth_token|access_token|refresh_token|oauth|signature|sig|auth"
KEYWORD_GROUPS["passwords"]="password|passwd|pwd|secret|credential|passphrase|auth|pin|pwdhash|hash|keyphrase|pass"
KEYWORD_GROUPS["admins"]="admin|root|user|login|superuser|administrator|sysadmin|manager|operator|owner|staff"
KEYWORD_GROUPS["databases"]="db|database|config|sql|mysql|mongo|pgsql|postgres|redis|cassandra|oracle|sqlite|connection|connstr|dsn"
KEYWORD_GROUPS["debug"]="debug|test|dev|staging|trace|verbose|beta|sandbox|mock|fake|dummy|trial|example|sample"
KEYWORD_GROUPS["keys"]="key|apikey|secretkey|privatekey|publickey|sshkey|gpgkey|tokenkey|accesskey|secret_access_key|secret_key"
KEYWORD_GROUPS["credentials"]="credential|username|user|userid|email|login|auth|password|pass|token|apikey|secret|sessionid|cookie"
KEYWORD_GROUPS["files"]="config|configfile|config.json|config.yaml|config.xml|backup|bak|old|save|archive|log|logfile|error.log|access.log"
KEYWORD_GROUPS["network"]="ip|ipaddress|hostname|host|url|endpoint|port|proxy|vpn|firewall|cidr|subnet|gateway|dns|domain"
KEYWORD_GROUPS["misc"]="cookie|session|csrf|jwt|oauth|nonce|signature|captcha|token|secret_token|auth_token|verification|otp|2fa|mfa"
KEYWORD_GROUPS["payment"]="creditcard|ccnum|cardnumber|cvv|cvc|expiry|billing|invoice|transaction|paypal|stripe|payment|bank|account"
KEYWORD_GROUPS["cloud"]="aws|azure|gcp|googlecloud|s3|bucket|iam|lambda|cloudfront|cloudtrail|kms|kmskey|secretmanager|vault|kms_key"

# Corrected NEW group for sensitive file extensions and filenames with double backslashes
KEYWORD_GROUPS["sensitive_files"]="\\.env|\\.env\\.backup|\\.env\\.bak|\\.gitignore|\\.htaccess|\\.htpasswd|\\.ssh/id_rsa|\\.pem|\\.key|\\.p12|\\.crt|\\.csr|\\.ovpn|\\.kdbx|\\.db|\\.sql|\\.sqlite|\\.log|\\.bak|\\.backup|\\.old|\\.save|\\.config|\\.zip|\\.tar\\.gz|\\.rar|\\.7z"

# Usage/help function
usage() {
  echo -e "${CYAN}Usage:${NC} $0 -f <input_file> [-k <custom_keywords_file>] [-o <output_file>]"
  echo -e "  -f <input_file>         File with URLs/endpoints to scan"
  echo -e "  -k <keywords_file>      (Optional) Custom keyword groups file"
  echo -e "  -o <output_file>        (Optional) Save results to this file"
  echo -e "  -h                      Show this help message"
  echo -e "\n${CYAN}Custom keywords file format:${NC}"
  echo -e "  groupname: keyword1|keyword2|keyword3"
  echo -e "  Example:"
  echo -e "    tokens: token|apikey|bearer"
  echo -e "    passwords: password|secret|auth"
  exit 1
}

# Parse arguments
while getopts ":f:k:o:h" opt; do
  case $opt in
    f) INPUT_FILE="$OPTARG" ;;
    k) CUSTOM_KEYWORDS="$OPTARG" ;;
    o) OUTPUT_FILE="$OPTARG" ;;
    h) usage ;;
    \?) echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2; usage ;;
    :) echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2; usage ;;
  esac
done

# Check input file
if [[ -z "$INPUT_FILE" ]]; then
  echo -e "${RED}[!] Input file is required.${NC}"
  usage
fi

if [[ ! -f "$INPUT_FILE" ]] || [[ ! -s "$INPUT_FILE" ]]; then
  echo -e "${RED}[!] Input file does not exist or is empty.${NC}"
  exit 1
fi

# Load custom keywords if provided
if [[ -n "$CUSTOM_KEYWORDS" ]]; then
  if [[ ! -f "$CUSTOM_KEYWORDS" ]]; then
    echo -e "${RED}[!] Custom keywords file does not exist.${NC}"
    exit 1
  fi
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    group=$(echo "$line" | cut -d: -f1 | xargs)
    words=$(echo "$line" | cut -d: -f2- | xargs)
    if [[ -n "$group" && -n "$words" ]]; then
      KEYWORD_GROUPS["$group"]="$words"
    fi
  done < "$CUSTOM_KEYWORDS"
fi

# Prepare output
exec 3>&1
if [[ -n "$OUTPUT_FILE" ]]; then
  exec > "$OUTPUT_FILE"
  echo -e "${GREEN}[*] Output will be saved to $OUTPUT_FILE${NC}" >&3
fi

echo -e "${CYAN}========== Bug Bounty Sensitive Keyword Finder ==========${NC}"
echo -e "Scanning file: ${YELLOW}$INPUT_FILE${NC}"
[[ -n "$CUSTOM_KEYWORDS" ]] && echo -e "Using custom keywords from: ${YELLOW}$CUSTOM_KEYWORDS${NC}"
echo

# Scan and summarize with highlighted keywords
total_matches=0
for group in "${!KEYWORD_GROUPS[@]}"; do
  pattern="${KEYWORD_GROUPS[$group]}"
  # Use grep with color, output line number and line
  matches=$(grep -Ein --color=always "$pattern" "$INPUT_FILE")

  count=$(echo "$matches" | grep -c .)
  if (( count > 0 )); then
    echo -e "${GREEN}[$group]${NC} (${count} matches):"
    # Print matches with highlighted keywords
    echo -e "${matches}"
    echo
    total_matches=$((total_matches + count))
  else
    echo -e "${CYAN}[$group]${NC}: No matches found."
    echo
  fi
done

echo -e "${CYAN}========== Summary ==========${NC}"
echo -e "Total matches found: ${YELLOW}$total_matches${NC}"
echo -e "Scan complete."

# Restore output if redirected
if [[ -n "$OUTPUT_FILE" ]]; then
  exec 1>&3
  echo -e "${GREEN}[*] Results saved to $OUTPUT_FILE${NC}"
fi

