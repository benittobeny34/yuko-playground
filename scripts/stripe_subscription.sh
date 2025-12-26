#!/bin/bash

API_KEY=""
OUTPUT="subscriptions.csv"

# Header (added price_id)
echo "sub_id,customer_id,customer_email,item_id,price_id,current_period_start,current_period_end,subscription_status" > "$OUTPUT"

URL="https://api.stripe.com/v1/subscriptions"
STARTING_AFTER=""

while true; do
  if [ -n "$STARTING_AFTER" ]; then
    RESPONSE=$(curl -s -G "$URL" \
      -u "$API_KEY:" \
      --data-urlencode "starting_after=$STARTING_AFTER" \
      --data-urlencode "expand[]=data.customer")
  else
    RESPONSE=$(curl -s -G "$URL" \
      -u "$API_KEY:" \
      --data-urlencode "expand[]=data.customer")
  fi

  echo "$RESPONSE" | jq -r '
    .data[]? |
    [
      .id,
      # customer ID (handle object or string)
      (if .customer == null then "" elif .customer | type == "object" then .customer.id else .customer end),
      # customer email (only if object)
      (if .customer | type == "object" then .customer.email else "" end),
      # first item ID
      (if .items.data[0]? then .items.data[0].id else "" end),
      # first item price ID
      (if .items.data[0]? then .items.data[0].price.id else "" end),
      # current period start
      (if .items.data[0]? then .items.data[0].current_period_start else "" end),
      # current period end
      (if .items.data[0]? then .items.data[0].current_period_end else "" end),
      # subscription status
      (.status // "")
    ] | @csv
  ' >> "$OUTPUT"

  HAS_MORE=$(echo "$RESPONSE" | jq -r ".has_more")

  if [ "$HAS_MORE" != "true" ]; then
    echo "Done! Saved to $OUTPUT"
    break
  fi

  STARTING_AFTER=$(echo "$RESPONSE" | jq -r ".data[-1].id")
done
