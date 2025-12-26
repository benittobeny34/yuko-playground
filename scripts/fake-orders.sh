#!/bin/bash

# WARNING: This script WILL create real orders in the WooCommerce store.
# Use only on test/staging, or with permission. Double confirm when prompted.

WC_URL="https://benitto-backend.ngrok.dev"
CONSUMER_KEY="ck_95442a418b4f01420b3f8bdc7123cb2197214dfd"
CONSUMER_SECRET="cs_b86080e617e979e8490a3e94473c031f905e862a"

TOTAL_ORDERS=50

# Max line items per order
MAX_ITEMS_PER_ORDER=4

# Max quantity per item
MAX_QTY=5

# Whether to use existing customers or create guest orders
USE_EXISTING_CUSTOMERS=true

# Payment/shipping placeholders
PAYMENT_METHOD="bacs"
PAYMENT_METHOD_TITLE="Direct Bank Transfer"
SHIPPING_METHOD="flat_rate"
SHIPPING_TITLE="Flat Rate"

# Safety confirmations
read -p "This script will create real orders at $WC_URL. Are you sure? (yes/no): " CONFIRM1
[[ "$CONFIRM1" != "yes" ]] && echo "Cancelled." && exit 1

read -p "Second confirmation. This action cannot be undone. Proceed? (yes/no): " CONFIRM2
[[ "$CONFIRM2" != "yes" ]] && echo "Cancelled." && exit 1

# Helper: random number between min/max
random_between() {
  local min=$1
  local max=$2
  echo $(( min + RANDOM % (max - min + 1) ))
}

# Function to generate random date within last 365 days in ISO 8601 format
generate_random_date() {
  DAYS_AGO=$((RANDOM % 365))
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    date -u -v-${DAYS_AGO}d +"%Y-%m-%dT%H:%M:%S"
  else
    # Linux
    date -u -d "$DAYS_AGO days ago" +"%Y-%m-%dT%H:%M:%S"
  fi
}

# Fetch products with pagination
echo "Fetching products..."
PRODUCTS_JSON="[]"
PAGE=1
while :; do
  PAGE_JSON=$(curl -s -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
    "$WC_URL/wp-json/wc/v3/products?per_page=100&page=$PAGE")

  COUNT=$(echo "$PAGE_JSON" | jq 'length')
  if [[ "$COUNT" -eq 0 ]]; then
    break
  fi
  PRODUCTS_JSON=$(jq -s 'add' <(echo "$PRODUCTS_JSON") <(echo "$PAGE_JSON"))
  PAGE=$((PAGE+1))
done

if echo "$PRODUCTS_JSON" | jq -e . >/dev/null 2>&1; then
  PRODUCT_IDS=($(echo "$PRODUCTS_JSON" | jq -r '.[].id'))
else
  echo "Failed to fetch products. Response:"
  echo "$PRODUCTS_JSON"
  exit 1
fi

if [ "${#PRODUCT_IDS[@]}" -eq 0 ]; then
  echo "No products found. Exiting."
  exit 1
fi
echo "Found ${#PRODUCT_IDS[@]} products."

# Fetch customers if enabled
CUSTOMER_IDS=()
if [ "$USE_EXISTING_CUSTOMERS" = true ]; then
  echo "Fetching customers..."
  CUSTOMERS_JSON=$(curl -s -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
    "$WC_URL/wp-json/wc/v3/customers?per_page=100")
  if echo "$CUSTOMERS_JSON" | jq -e . >/dev/null 2>&1; then
    CUSTOMER_IDS=($(echo "$CUSTOMERS_JSON" | jq -r '.[].id'))
  else
    echo "Failed to fetch customers; continuing with guest orders."
    USE_EXISTING_CUSTOMERS=false
  fi
  echo "Found ${#CUSTOMER_IDS[@]} customers."
fi

created=0
for i in $(seq 1 $TOTAL_ORDERS); do
  echo "Preparing order $i / $TOTAL_ORDERS ..."

  CUSTOMER_PART=""
  BILLING_JSON=""

  # Decide customer: existing or guest
  if [ "$USE_EXISTING_CUSTOMERS" = true ] && [ "${#CUSTOMER_IDS[@]}" -gt 0 ]; then
    if [ $((RANDOM % 100)) -lt 80 ]; then
      IDX=$((RANDOM % ${#CUSTOMER_IDS[@]}))
      CUSTOMER_ID=${CUSTOMER_IDS[$IDX]}
      CUSTOMER_PART="\"customer_id\": $CUSTOMER_ID,"
    else
      GNAME="Guest$(date +%s | tail -c 4)"

      GEMAIL="$(echo "$GNAME" | tr '[:upper:]' '[:lower:]')@example.com"
      BILLING_JSON="\"billing\": {\"first_name\":\"$GNAME\",\"last_name\":\"User\",\"address_1\":\"123 Test St\",\"city\":\"Testville\",\"state\":\"TestState\",\"postcode\":\"12345\",\"country\":\"US\",\"email\":\"$GEMAIL\",\"phone\":\"0123456789\"},\"shipping\":{\"first_name\":\"$GNAME\",\"last_name\":\"User\",\"address_1\":\"123 Test St\",\"city\":\"Testville\",\"state\":\"TestState\",\"postcode\":\"12345\",\"country\":\"US\"},"
    fi
  else

    GNAME="Guest$(date +%s | tail -c 4)"
    GEMAIL="$(echo "$GNAME" | tr '[:upper:]' '[:lower:]')@example.com"
    BILLING_JSON="\"billing\": {\"first_name\":\"$GNAME\",\"last_name\":\"User\",\"address_1\":\"123 Test St\",\"city\":\"Testville\",\"state\":\"TestState\",\"postcode\":\"12345\",\"country\":\"US\",\"email\":\"$GEMAIL\",\"phone\":\"0123456789\"},\"shipping\":{\"first_name\":\"$GNAME\",\"last_name\":\"User\",\"address_1\":\"123 Test St\",\"city\":\"Testville\",\"state\":\"TestState\",\"postcode\":\"12345\",\"country\":\"US\"},"
  fi

  # Random line items
  ITEMS_COUNT=$(random_between 1 $MAX_ITEMS_PER_ORDER)
  LINE_ITEMS_JSON=""
  for j in $(seq 1 $ITEMS_COUNT); do
    IDX=$((RANDOM % ${#PRODUCT_IDS[@]}))
    PID=${PRODUCT_IDS[$IDX]}
    QTY=$(random_between 1 $MAX_QTY)
    ITEM="{\"product_id\": $PID, \"quantity\": $QTY}"
    if [ -z "$LINE_ITEMS_JSON" ]; then
      LINE_ITEMS_JSON="$ITEM"
    else
      LINE_ITEMS_JSON="$LINE_ITEMS_JSON, $ITEM"
    fi
  done

  # Shipping line
  SHIPPING_JSON="\"shipping_lines\": [{\"method_id\": \"$SHIPPING_METHOD\",\"method_title\": \"$SHIPPING_TITLE\",\"total\": \"5.00\"}],"

  # Generate random created date
  RANDOM_DATE=$(generate_random_date)

  # Final order JSON
  ORDER_JSON="{$CUSTOMER_PART$BILLING_JSON\"payment_method\":\"$PAYMENT_METHOD\",\"payment_method_title\":\"$PAYMENT_METHOD_TITLE\",\"set_paid\":true,\"date_created\":\"$RANDOM_DATE\",\"line_items\":[$LINE_ITEMS_JSON],$SHIPPING_JSON\"status\":\"processing\"}"

  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$WC_URL/wp-json/wc/v3/orders" \
    -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
    -H "Content-Type: application/json" \
    -d "$ORDER_JSON")

  HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
    echo "Order created successfully."
    created=$((created+1))
  else
    echo "Failed to create order (HTTP $HTTP_STATUS). Response:"
    echo "$BODY"
    echo "$(date -u) - Failed order creation: $BODY" >> failed_orders.log
  fi

  # Small random delay
  sleep $(awk -v min=0.5 -v max=1.5 'BEGIN{srand(); print min+rand()*(max-min)}')
done

echo "Done. Created $created / $TOTAL_ORDERS orders."

