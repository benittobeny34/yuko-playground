#!/bin/bash

# Store 1 Configuration
WC_URL_1="https://benitto-backend.ngrok.dev"
CONSUMER_KEY_1="ck_7d314e948188c16a4d82687f1f9e2720ebdb7a37"
CONSUMER_SECRET_1="cs_9e3144420ef1cd88f7928b637ea33c13f1ee2a4a"

# Store 2 Configuration
WC_URL_2="https://benitto-frontend.ngrok.dev"
CONSUMER_KEY_2="ck_35e07b78412714c61c1c180b1e0f42b52bfd826c"
CONSUMER_SECRET_2="cs_d9561f06e27a62aca9f5289bd3393b1ccae541ae"

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRODUCTS_FILE="$SCRIPT_DIR/syndication-products.json"

# Check if products file exists
if [ ! -f "$PRODUCTS_FILE" ]; then
  echo "Error: Products file not found at $PRODUCTS_FILE"
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Please install jq to parse JSON."
  echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
  exit 1
fi

# Read products from JSON file
PRODUCTS=$(cat "$PRODUCTS_FILE")
PRODUCT_COUNT=$(echo "$PRODUCTS" | jq 'length')

echo "=========================================="
echo "Creating Products for Review Syndication"
echo "Found $PRODUCT_COUNT products in $PRODUCTS_FILE"
echo "=========================================="
echo ""

# Function to create product in a store
create_product() {
  local url=$1
  local key=$2
  local secret=$3
  local product_data=$4
  local store_name=$5

  product_name=$(echo "$product_data" | jq -r '.name')
  product_sku=$(echo "$product_data" | jq -r '.sku')

  echo "Creating: $product_name (SKU: $product_sku) in $store_name..."

  # Build product JSON
  product_json=$(echo "$product_data" | jq '
    {
      name: .name,
      type: .type,
      regular_price: .regular_price,
      sku: .sku,
      description: .description,
      short_description: .short_description
    }
  ')

  # Create product
  response=$(curl -s -X POST "$url/wp-json/wc/v3/products" \
    -u "$key:$secret" \
    -H "Content-Type: application/json" \
    -d "$product_json")

  product_id=$(echo "$response" | jq -r '.id // empty')

  if [ -n "$product_id" ] && [ "$product_id" != "null" ]; then
    echo "✓ Created: $product_name (Product ID: $product_id, SKU: $product_sku)"
  else
    echo "✗ Failed to create product: $product_name"
    error_msg=$(echo "$response" | jq -r '.message // .error // empty')
    if [ -n "$error_msg" ]; then
      echo "  Error: $error_msg"
    fi
  fi
  echo ""
}

# Create products in Store 1
echo "==========================================="
echo "Creating products in Store 1..."
echo "URL: $WC_URL_1"
echo "==========================================="
echo ""

for i in $(seq 0 $((PRODUCT_COUNT - 1))); do
  product_data=$(echo "$PRODUCTS" | jq -c ".[$i]")
  create_product "$WC_URL_1" "$CONSUMER_KEY_1" "$CONSUMER_SECRET_1" "$product_data" "Store 1"
done

echo "==========================================="
echo ""

# Create products in Store 2
echo "==========================================="
echo "Creating products in Store 2..."
echo "URL: $WC_URL_2"
echo "==========================================="
echo ""

if [ "$WC_URL_2" == "YOUR_SECOND_STORE_URL" ]; then
  echo "⚠️  WARNING: Please update Store 2 credentials in the script!"
  echo "Edit the script and replace:"
  echo "  - WC_URL_2"
  echo "  - CONSUMER_KEY_2"
  echo "  - CONSUMER_SECRET_2"
  echo ""
  echo "Skipping Store 2..."
else
  for i in $(seq 0 $((PRODUCT_COUNT - 1))); do
    product_data=$(echo "$PRODUCTS" | jq -c ".[$i]")
    create_product "$WC_URL_2" "$CONSUMER_KEY_2" "$CONSUMER_SECRET_2" "$product_data" "Store 2"
  done
fi

echo "==========================================="
echo "Done! $PRODUCT_COUNT products with matching SKUs created."
echo "==========================================="
