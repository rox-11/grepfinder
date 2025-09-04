#!/bin/bash
# Colors for output
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color

# Subdomain keyword groups (example.com subdomains without domain suffix)
declare -A KEYWORD_GROUPS
KEYWORD_GROUPS["subdomains"]="admin|api|dev|staging|test|beta|internal|intranet|vpn|mail|webmail|portal|auth|login|sso|dashboard|cms|crm|static|uploads|git|ci|jenkins|db|logs|monitor|payments|support|root|legacy|dev-api|mobile-api|partner|review|qa|config|user|secure|debug|files|backup|adminpanel|controlpanel|shell|ssh|ftp|gitlab|gitbucket|github|bitbucket|svn|docker|k8s|kubernetes|qa-api|sandbox|bastion|proxy|mx|imap|pop3|smtp|api-v2|api-v1|analytics|admin-api|assets|auth-api|billing|cdn|chat|crm-api|docs|email|encryption|es|exchange|firewall|ftpserver|gateway|groups|help|influxdb|instance|inventory|jobs|kaiser|ldap|loadbalancer|logs-api|media|media-api|mgmt|mq|mx1|mx2|ns1|ns2|oauth2|ops|orchestration|payment-api|payments-api|plan|platform|portal-api|private|proxy-api|qa-panel|qa-dashboard|queue|rbac|redis|registry|release|remote|reports|resources|sandbox-api|search|secure-api|security|server|services|shell-ui|smtp-api|soap|sql|ssh-api|static-api|storage|svn-api|support-api|sync|test-api|tracking|tasks|uat|user-api|version|webhook|webapi|waf|workflow"

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
  echo -e "    subdomains: admin|api|dev"
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

# Validate input file
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

# Prepare output redirection if specified
exec 3>&1
if [[ -n "$OUTPUT_FILE" ]]; then
  exec > "$OUTPUT_FILE"
  echo -e "${GREEN}[*] Output will be saved to $OUTPUT_FILE${NC}" >&3
fi

echo -e "${CYAN}========== Subdomain Keyword Finder ==========${NC}"
echo -e "Scanning file: ${YELLOW}$INPUT_FILE${NC}"
[[ -n "$CUSTOM_KEYWORDS" ]] && echo -e "Using custom keywords from: ${YELLOW}$CUSTOM_KEYWORDS${NC}"
echo

# Scan and summarize with highlighted keywords
total_matches=0
for group in "${!KEYWORD_GROUPS[@]}"; do
  pattern="${KEYWORD_GROUPS[$group]}"
  matches=$(grep -Ein --color=always "$pattern" "$INPUT_FILE")
  count=$(echo "$matches" | grep -c .)
  if (( count > 0 )); then
    echo -e "${GREEN}[$group]${NC} (${count} matches):"
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

# Restore stdout if redirected
if [[ -n "$OUTPUT_FILE" ]]; then
  exec 1>&3
  echo -e "${GREEN}[*] Results saved to $OUTPUT_FILE${NC}"
fi

