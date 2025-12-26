#!/bin/bash

# WooCommerce API credentials
WC_URL="https://benitto-backend.ngrok.dev"
CONSUMER_KEY="ck_95442a418b4f01420b3f8bdc7123cb2197214dfd"
CONSUMER_SECRET="cs_b86080e617e979e8490a3e94473c031f905e862a"

# Number of customers to create
NUM_CUSTOMERS=${1:-30}   # default 5, or pass as argument

echo "Creating $NUM_CUSTOMERS customers asynchronously in WooCommerce..."

for i in $(seq 1 "$NUM_CUSTOMERS"); do
  timestamp=$(date +%s)
  email="user${i}_${timestamp}@example.com"
  username="user${i}_${timestamp}"
  first="User"
  last="Test${i}_${timestamp}"

  curl -s -X POST "$WC_URL/wp-json/wc/v3/customers" \
    -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
    -H "Content-Type: application/json" \
    -d "{
      \"email\": \"$email\",
      \"first_name\": \"$first\",
      \"last_name\": \"$last\",
      \"username\": \"$username\",
      \"billing\": {
        \"first_name\": \"$first\",
        \"last_name\": \"$last\",
        \"address_1\": \"123 Test Street\",
        \"city\": \"Testville\",
        \"state\": \"CA\",
        \"postcode\": \"90001\",
        \"country\": \"US\",
        \"email\": \"$email\",
        \"phone\": \"1234567890\"
      },
      \"shipping\": {
        \"first_name\": \"$first\",
        \"last_name\": \"$last\",
        \"address_1\": \"123 Test Street\",
        \"city\": \"Testville\",
        \"state\": \"CA\",
        \"postcode\": \"90001\",
        \"country\": \"US\"
      }
    }" > /dev/null &
done

wait
echo "✅ Done! Created $NUM_CUSTOMERS customers."
