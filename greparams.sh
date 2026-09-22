#!/bin/bash

# Colors for output
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color

if [ -z "$1" ];then
       echo -e "./greparams.sh <${RED}file.txt${NC}>" 
		exit 1
else

	cat $1 | grep -E "\?|\&|\%3F|\%253F|\%26|\%2526" 2>/dev/null |sed -E 's/([?&][^=]+=)[^&#]*/\1roox/g'| sort | uniq > params_result.txt
fi
read -p "Basic test for SSRF BXSS [Y/N]: " SSRFTest
if [ $SSRFTest = "Y" ];then
	read -p "bxss payload or Webhook url : " WBHK
	#echo $WBHK | sed 's|^https://||' $NWBHK
	sed -E 's/([?&][^=]+=)[^&#]*/\1https:\/\/'''$WBHK'''/g' params_result.txt > ssrf_result.txt 
	while read -r line;do
		echo -e "${YELLOW}PING:${NC}" && ping -n 1 $line
	done<ssrf_result.txt
else
	exit 1
fi
