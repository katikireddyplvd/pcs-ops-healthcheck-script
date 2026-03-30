#!/bin/bash

# ===== Colors =====
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

URL_FILE="urls.txt"

echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}Squid Connectivity Health Check${NC}"
echo -e "${YELLOW}=========================================${NC}"

if [ ! -f "$URL_FILE" ]; then
  echo "ERROR: urls.txt not found!"
  exit 1
fi

read -p "Enter Plant Name (e.g. dekas-02): " PLANT
read -p "Enter Environment (qa / prod): " ENV

echo ""
echo -e "${CYAN}Available Modes:${NC}"
echo "----------------------------------------------------"
echo "a  -> External Proxy (Plant Proxy) WITH LDAP Auth"
echo "      proxy.<env>.<plant>.pcs.vwgroup.com:8080"
echo ""
echo "b  -> Internal Squid Forward Proxy WITH LDAP Auth"
echo "      http://squid-forward-internal:3128"
echo ""
echo "c  -> External Proxy (Plant Proxy) WITHOUT Auth"
echo ""
echo "d  -> Internal Squid Forward Proxy WITHOUT Auth"
echo "----------------------------------------------------"
echo "Example: a,b   OR   a,b,c,d"
echo ""

read -p "Enter Mode(s): " MODES

MODES=$(echo "$MODES" | tr '[:upper:]' '[:lower:]')
IFS=',' read -ra MODE_ARRAY <<< "$MODES"

# ===== LDAP Check =====
LDAP_REQUIRED=0
for MODE in "${MODE_ARRAY[@]}"; do
  MODE=$(echo "$MODE" | xargs)
  if [[ "$MODE" == "a" || "$MODE" == "b" ]]; then
    LDAP_REQUIRED=1
  fi
done

if [ "$LDAP_REQUIRED" -eq 1 ]; then
  echo ""
  read -p "Enter LDAP Username: " LDAP_USER
  read -s -p "Enter LDAP Password: " LDAP_PASS
  echo ""
fi

# ===== Process Each Mode =====
for MODE in "${MODE_ARRAY[@]}"
do
  MODE=$(echo "$MODE" | xargs)
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  LOG_FILE="squid_${MODE}_${TIMESTAMP}.log"

  echo -e "${YELLOW}Running Mode: $MODE${NC}"
  echo "Log File: $LOG_FILE"

  case "$MODE" in
    a)
      PROXY="proxy.${ENV}.${PLANT}.pcs.vwgroup.com:8080"
      AUTH="--proxy-user ${LDAP_USER}:${LDAP_PASS}"
      ;;
    b)
      PROXY="http://squid-forward-internal:3128"
      AUTH="--proxy-user ${LDAP_USER}:${LDAP_PASS}"
      ;;
    c)
      PROXY="proxy.${ENV}.${PLANT}.pcs.vwgroup.com:8080"
      AUTH=""
      ;;
    d)
      PROXY="http://squid-forward-internal:3128"
      AUTH=""
      ;;
    *)
      echo "Invalid Mode: $MODE"
      continue
      ;;
  esac

  while IFS= read -r URL || [[ -n "$URL" ]]
  do
    URL=$(echo "$URL" | tr -d '\r' | xargs)
    [ -z "$URL" ] && continue

    echo -e "${CYAN}Testing: $URL${NC}"

    echo "====================================================" >> "$LOG_FILE"
    echo "URL: $URL" >> "$LOG_FILE"
    echo "Time: $(date)" >> "$LOG_FILE"
    echo "Proxy Used: $PROXY" >> "$LOG_FILE"
    echo "----------------------------------------------------" >> "$LOG_FILE"

    echo "Command Used:" >> "$LOG_FILE"
    echo "curl -k --proxy $PROXY $AUTH $URL" >> "$LOG_FILE"
    echo "----------------------------------------------------" >> "$LOG_FILE"

    # Direct HTTP Code capture (clean method)
    HTTP_CODE=$(curl -k \
      --proxy "$PROXY" \
      $AUTH \
      --header "Connection: close" \
      --no-keepalive \
      --max-time 20 \
      -o /dev/null \
      -s \
      -w "%{http_code}" \
      "$URL")

    [ -z "$HTTP_CODE" ] && HTTP_CODE="000"

    echo "FINAL_HTTP_STATUS: $HTTP_CODE" >> "$LOG_FILE"
    echo "====================================================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    echo -e "${GREEN}HTTP Code: $HTTP_CODE${NC}"

  done < "$URL_FILE"

  echo ""
  echo -e "${YELLOW}Mode $MODE Completed${NC}"
  echo "Log File: $LOG_FILE"
  echo ""

done

echo -e "${YELLOW}All selected modes completed.${NC}"
