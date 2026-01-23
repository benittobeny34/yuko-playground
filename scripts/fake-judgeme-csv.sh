#!/bin/bash

WC_URL="https://benitto-backend.ngrok.dev"
CONSUMER_KEY="ck_074f9692625287a06928986353f45dd3eb3b0149"
CONSUMER_SECRET="cs_15826810396729e825ef2911932255ca6e3e9677"
# WC_URL="https://floralwhite-wildcat-321136.hostingersite.com"
# CONSUMER_KEY="ck_ad3107d90850e739f16076f09b6060f0ad7ad084"
# CONSUMER_SECRET="cs_e9a7c184fadca4c59073abec0de3d9f7a2fd97c6"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Output CSV file with timestamp
OUTPUT_FILE="../fake_reviews_${TIMESTAMP}.csv"
# Number of reviews per product
REVIEWS_PER_PRODUCT=15
# Number of store reviews (without product_id)
STORE_REVIEWS_COUNT=1

# Arrays of fake names with international characters
NAMES=(
  "Alice" "Bob" "Charlie" "David" "Eve" "Frank" "Grace" "Hannah"
  "Ivan" "Julia" "Kevin" "Laura" "Michael" "Nina" "Oscar" "Paula"
  "Quentin" "Rachel" "Steve" "Tina" "Uma" "Victor" "Wendy" "Xander"
  "Yara" "Zach" "José" "François" "María" "André" "Sofía" "Müller"
  "李明" "田中" "김민준" "Владимир" "محمد" "Αλέξης"
)

# Sample public placeholder images
IMAGES=(
  "https://images.pexels.com/photos/30716366/pexels-photo-30716366.jpeg"
  "https://picsum.photos/seed/pic2/300/300"
  "https://picsum.photos/seed/pic3/300/300"
  # "https://picsum.photos/seed/pic4/300/300"
  # "https://picsum.photos/seed/pic5/300/300"
)

# Function to generate fake comment with emojis and multilingual content
generate_comment() {
    # Words with emojis and special characters
    WORDS=(
        "excellent" "amazing" "great" "wonderful" "fantastic" "superb" "quality"
        "快速配送" "très bien" "muy bueno" "отлично" "رائع" "perfect"
        "love it" "highly recommend" "worth buying" "satisfied" "快適" "좋아요"
        "discount 🎟️" "coupon 🎫" "deal 💰" "shipping 📦" "fast ⚡" "quality ✨"
        "happy 😊" "perfect 👌" "recommended 👍" "amazing 🌟" "excellent 💯"
    )

    COUNT=$((RANDOM % 8 + 5))  # 5–12 words
    COMMENT=""

    for i in $(seq 1 $COUNT); do
        WORD=${WORDS[$RANDOM % ${#WORDS[@]}]}
        COMMENT="$COMMENT $WORD"
    done

    # Randomly add emoji at the end (50% chance)
    if (( RANDOM % 2 == 0 )); then
        EMOJIS=("😊" "👍" "⭐" "💯" "🎉" "❤️" "🔥" "✨" "👌" "🎁" "🎟️" "🎫")
        EMOJI=${EMOJIS[$RANDOM % ${#EMOJIS[@]}]}
        COMMENT="$COMMENT $EMOJI"
    fi

    COMMENT="$(echo "$COMMENT" | sed 's/^ //')"
    echo "$COMMENT"
}

# Function to generate random date within last 365 days
generate_random_date() {
    DAYS_AGO=$((RANDOM % 365))
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        date -u -v-${DAYS_AGO}d +"%Y-%m-%d %H:%M:%S"
    else
        # Linux
        date -u -d "$DAYS_AGO days ago" +"%Y-%m-%d %H:%M:%S"
    fi
}

# Write Judge.me headers
echo "title,body,rating,review_date,source,curated,reviewer_name,reviewer_email,product_id,product_handle,reply,reply_date,picture_urls,ip_address,location" > "$OUTPUT_FILE"

# Fetch product IDs and handles (first 100 products)
PRODUCTS=$(curl -s -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
    "$WC_URL/wp-json/wc/v3/products?per_page=100" | jq -r '.[] | [.id, .slug] | @csv')

# Loop through each product
while IFS=, read -r PRODUCT_ID PRODUCT_HANDLE; do
    PRODUCT_HANDLE=$(echo "$PRODUCT_HANDLE" | tr -d '"')
    echo "Generating fake reviews for product ID $PRODUCT_ID..."

    for i in $(seq 1 $REVIEWS_PER_PRODUCT); do
        REVIEWER=${NAMES[$RANDOM % ${#NAMES[@]}]}
        EMAIL="$(echo "$REVIEWER" | tr '[:upper:]' '[:lower:]')$RANDOM@example.com"

        # Randomly set some emails as anonymous (20% chance)
        if (( RANDOM % 5 == 0 )); then
            EMAIL="support+anonymous@judge.me"
        fi

        # Generate title with emojis and multilingual content
        TITLES=(
            "Great product! 👍"
            "Amazing quality ⭐"
            "Highly recommend 💯"
            "Perfect! 😊"
            "Love it ❤️"
            "Excellent service ✨"
            "Worth every penny 🎉"
            "素晴らしい商品"
            "Très bon produit"
            "Excelente producto"
            "Отличный товар"
            "Got it with coupon 🎟️"
            "Great deal 💰"
            "منتج رائع"
        )
        TITLE=${TITLES[$RANDOM % ${#TITLES[@]}]}
        BODY=$(generate_comment)
        RATING=$((RANDOM % 5 + 1))
        DATE=$(generate_random_date)

        # Randomly set curated field: ok, spam, or empty
        RAND_CURATED=$((RANDOM % 10))
        if (( RAND_CURATED < 7 )); then
            CURATED="ok"
        elif (( RAND_CURATED < 9 )); then
            CURATED="spam"
        else
            CURATED=""
        fi

        # Randomly add reply + reply_date
        if (( RANDOM % 3 == 0 )); then
            REPLY="Thanks for your review!"
            REPLY_DATE=$(date -u +"%Y-%m-%d %H:%M:%S")
        else
            REPLY=""
            REPLY_DATE=""
        fi

        # Randomly add up to 3 pictures
        PICS=""
        # PIC_COUNT=0
        PIC_COUNT=$((RANDOM % 4)) # 0–3
        if (( PIC_COUNT > 0 )); then
            for j in $(seq 1 $PIC_COUNT); do
                PIC=${IMAGES[$RANDOM % ${#IMAGES[@]}]}
                if [ -z "$PICS" ]; then
                    PICS="$PIC"
                else
                    PICS="$PICS,$PIC"
                fi
            done
        fi

        # Append to CSV
        echo "\"$TITLE\",\"$BODY\",$RATING,\"$DATE\",\"email\",\"$CURATED\",\"$REVIEWER\",\"$EMAIL\",$PRODUCT_ID,\"$PRODUCT_HANDLE\",\"$REPLY\",\"$REPLY_DATE\",\"$PICS\",\"\",\"\"" >> "$OUTPUT_FILE"
    done
done <<< "$PRODUCTS"

# Generate store reviews (without product_id)
echo "Generating $STORE_REVIEWS_COUNT store reviews (without product_id)..."
for i in $(seq 1 $STORE_REVIEWS_COUNT); do
    REVIEWER=${NAMES[$RANDOM % ${#NAMES[@]}]}
    EMAIL="$(echo "$REVIEWER" | tr '[:upper:]' '[:lower:]')$RANDOM@example.com"

    # Randomly set some emails as anonymous (20% chance)
    if (( RANDOM % 5 == 0 )); then
        EMAIL="support+anonymous@judge.me"
    fi

    # Generate title with emojis and multilingual content for store reviews
    STORE_TITLES=(
        "Great store experience! 👍"
        "Amazing store ⭐"
        "Best online shop 💯"
        "Perfect shopping 😊"
        "Love this store ❤️"
        "Excellent customer service ✨"
        "Fast delivery 🚀"
        "素晴らしいストア"
        "Excellente boutique"
        "Tienda excelente"
        "Отличный магазин"
        "Used store coupon 🎫"
        "Great deals 🎁"
    )
    TITLE=${STORE_TITLES[$RANDOM % ${#STORE_TITLES[@]}]}
    BODY=$(generate_comment)
    RATING=$((RANDOM % 5 + 1))
    DATE=$(date -u +"%Y-%m-%d %H:%M:%S")

    # Randomly set curated field: ok, spam, or empty
    RAND_CURATED=$((RANDOM % 10))
    if (( RAND_CURATED < 7 )); then
        CURATED="ok"
    elif (( RAND_CURATED < 9 )); then
        CURATED="spam"
    else
        CURATED=""
    fi

    # Randomly add reply + reply_date
    if (( RANDOM % 3 == 0 )); then
        REPLY="Thanks for your review!"
        REPLY_DATE=$(date -u +"%Y-%m-%d %H:%M:%S")
    else
        REPLY=""
        REPLY_DATE=""
    fi

    # Randomly add up to 3 pictures
    PICS=""
    # PIC_COUNT=2
    PIC_COUNT=$((RANDOM % 4)) # 0–3
    if (( PIC_COUNT > 0 )); then
        for j in $(seq 1 $PIC_COUNT); do
            PIC=${IMAGES[$RANDOM % ${#IMAGES[@]}]}
            if [ -z "$PICS" ]; then
                PICS="$PIC"
            else
                PICS="$PICS,$PIC"
            fi
        done
    fi

    # Append to CSV with empty product_id and product_handle for store reviews
    echo "\"$TITLE\",\"$BODY\",$RATING,\"$DATE\",\"WooCommerce\",\"$CURATED\",\"$REVIEWER\",\"$EMAIL\",\"\",\"\",\"$REPLY\",\"$REPLY_DATE\",\"$PICS\",\"\",\"\"" >> "$OUTPUT_FILE"
done

echo "✅ Fake Judge.me CSV generated at $OUTPUT_FILE"
echo "   - Product reviews: $(wc -l <<< "$PRODUCTS") products × $REVIEWS_PER_PRODUCT reviews each"
echo "   - Store reviews (no product_id): $STORE_REVIEWS_COUNT"

