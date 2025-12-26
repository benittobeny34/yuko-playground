#!/bin/bash
SHOP_DOMAIN="review-wprelay.myshopify.com"
ACCESS_TOKEN=""

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="./shopify_fake_reviews_${TIMESTAMP}.csv"

# Reviews per product and store reviews
REVIEWS_PER_PRODUCT=2
STORE_REVIEWS_COUNT=0

# Names and images
NAMES=(Alice Bob Charlie David Eve Frank Grace Hannah Ivan Julia Kevin Laura Michael Nina Oscar Paula Quentin Rachel Steve Tina Uma Victor Wendy Xander Yara Zach)
IMAGES=(
  "https://images.pexels.com/photos/30716366/pexels-photo-30716366.jpeg"
  "https://picsum.photos/seed/pic2/300/300"
  "https://picsum.photos/seed/pic3/300/300"
  "https://picsum.photos/seed/pic4/300/300"
  "https://picsum.photos/seed/pic5/300/300"
)

# Helpers
generate_comment() {
  WORDS=(lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua ut enim ad minim veniam)
  COUNT=$((RANDOM % 12 + 8))
  COMMENT=""
  for i in $(seq 1 $COUNT); do
    COMMENT="$COMMENT ${WORDS[$RANDOM % ${#WORDS[@]}]}"
  done
  COMMENT="$(tr '[:lower:]' '[:upper:]' <<< ${COMMENT:1:1})${COMMENT:2}."
  echo "$COMMENT"
}

generate_random_date() {
  DAYS_AGO=$((RANDOM % 365))
  if [[ "$OSTYPE" == "darwin"* ]]; then
    date -u -v-${DAYS_AGO}d +"%Y-%m-%d %H:%M:%S"
  else
    date -u -d "$DAYS_AGO days ago" +"%Y-%m-%d %H:%M:%S"
  fi
}

# Header (Judge.me-style)
echo 'title,body,rating,review_date,source,curated,reviewer_name,reviewer_email,product_id,product_handle,reply,reply_date,picture_urls,ip_address,location,metaobject_handle' > "$OUTPUT_FILE"

# Fetch first 100 products (adjust limit/page if needed)
PRODUCTS=$(curl -s -H "X-Shopify-Access-Token: $ACCESS_TOKEN" \
  "https://${SHOP_DOMAIN}/admin/api/2023-10/products.json?limit=100" | \
  jq -r '.products[] | [.id, .handle] | @csv')

# Generate product reviews
while IFS=, read -r PRODUCT_ID PRODUCT_HANDLE; do
  PRODUCT_HANDLE=$(echo "$PRODUCT_HANDLE" | tr -d '"')
  echo "Generating fake reviews for product ID $PRODUCT_ID..."
  for i in $(seq 1 $REVIEWS_PER_PRODUCT); do
    REVIEWER=${NAMES[$RANDOM % ${#NAMES[@]}]}
    EMAIL="$(echo "$REVIEWER" | tr '[:upper:]' '[:lower:]')$RANDOM@example.com"
    [[ $((RANDOM % 5)) -eq 0 ]] && EMAIL="support+anonymous@judge.me"
    TITLE="Great product!"
    BODY=$(generate_comment)
    RATING=$((RANDOM % 5 + 1))
    DATE=$(generate_random_date)

    # curated: ok/spam/blank
    RAND_CURATED=$((RANDOM % 10))
    if (( RAND_CURATED < 7 )); then CURATED="ok"
    elif (( RAND_CURATED < 9 )); then CURATED="spam"
    else CURATED=""; fi

    # reply
    if (( RANDOM % 3 == 0 )); then
      REPLY="Thanks for your review!"
      REPLY_DATE=$(date -u +"%Y-%m-%d %H:%M:%S")
    else
      REPLY=""; REPLY_DATE=""
    fi

    # pictures
    PICS=""; PIC_COUNT=$((RANDOM % 4))
    if (( PIC_COUNT > 0 )); then
      for j in $(seq 1 $PIC_COUNT); do
        PIC=${IMAGES[$RANDOM % ${#IMAGES[@]}]}
        [[ -z "$PICS" ]] && PICS="$PIC" || PICS="$PICS,$PIC"
      done
    fi

    # metaobject_handle blank by default
    echo "\"$TITLE\",\"$BODY\",$RATING,\"$DATE\",\"email\",\"$CURATED\",\"$REVIEWER\",\"$EMAIL\",$PRODUCT_ID,\"$PRODUCT_HANDLE\",\"$REPLY\",\"$REPLY_DATE\",\"$PICS\",\"\",\"\",\"\"" >> "$OUTPUT_FILE"
  done
done <<< "$PRODUCTS"

# Store reviews (no product_id)
echo "Generating $STORE_REVIEWS_COUNT store reviews..."
for i in $(seq 1 $STORE_REVIEWS_COUNT); do
  REVIEWER=${NAMES[$RANDOM % ${#NAMES[@]}]}
  EMAIL="$(echo "$REVIEWER" | tr '[:upper:]' '[:lower:]')$RANDOM@example.com"
  [[ $((RANDOM % 5)) -eq 0 ]] && EMAIL="support+anonymous@judge.me"
  TITLE="Great store experience!"
  BODY=$(generate_comment)
  RATING=$((RANDOM % 5 + 1))
  DATE=$(date -u +"%Y-%m-%d %H:%M:%S")

  RAND_CURATED=$((RANDOM % 10))
  if (( RAND_CURATED < 7 )); then CURATED="ok"
  elif (( RAND_CURATED < 9 )); then CURATED="spam"
  else CURATED=""; fi

  if (( RANDOM % 3 == 0 )); then
    REPLY="Thanks for your review!"; REPLY_DATE=$(date -u +"%Y-%m-%d %H:%M:%S")
  else
    REPLY=""; REPLY_DATE=""
  fi

  PICS=""; PIC_COUNT=$((RANDOM % 4))
  if (( PIC_COUNT > 0 )); then
    for j in $(seq 1 $PIC_COUNT); do
      PIC=${IMAGES[$RANDOM % ${#IMAGES[@]}]}
      [[ -z "$PICS" ]] && PICS="$PIC" || PICS="$PICS,$PIC"
    done
  fi

  echo "\"$TITLE\",\"$BODY\",$RATING,\"$DATE\",\"shopify\",\"$CURATED\",\"$REVIEWER\",\"$EMAIL\",\"\",\"\",\"$REPLY\",\"$REPLY_DATE\",\"$PICS\",\"\",\"\",\"\"" >> "$OUTPUT_FILE"
done

echo "✅ Fake Judge.me CSV generated at $OUTPUT_FILE"
echo "   - Product reviews: $(wc -l <<< \"$PRODUCTS\") products × $REVIEWS_PER_PRODUCT each"
echo "   - Store reviews: $STORE_REVIEWS_COUNT"
