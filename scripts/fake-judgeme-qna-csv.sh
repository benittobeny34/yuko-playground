#!/bin/bash

#Woocommerce API credentials
WC_URL="https://benitto-backend.ngrok.dev"
CONSUMER_KEY="ck_7d314e948188c16a4d82687f1f9e2720ebdb7a37"
CONSUMER_SECRET="cs_9e3144420ef1cd88f7928b637ea33c13f1ee2a4a"
# WC_URL="https://floralwhite-wildcat-321136.hostingersite.com"
# CONSUMER_KEY="ck_ad3107d90850e739f16076f09b6060f0ad7ad084"
# CONSUMER_SECRET="cs_e9a7c184fadca4c59073abec0de3d9f7a2fd97c6"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Output CSV file with timestamp
OUTPUT_FILE="fake_qna_${TIMESTAMP}.csv"
# Number of questions per product
QUESTIONS_PER_PRODUCT=10

# Arrays of fake names
ASKER_NAMES=(
  "Alice Johnson" "Bob Martinez" "Charlie Wong" "David Kumar" "Eve Anderson"
  "Frank Williams" "Grace Lee" "Hannah Brown" "Ivan Rodriguez" "Julia Chen"
  "Kevin Davis" "Laura Garcia" "Michael Thompson" "Nina Patel" "Oscar Kim"
  "Paula Miller" "Quentin Taylor" "Rachel Wilson" "Steve Moore" "Tina Jackson"
)

ANSWERER_NAMES=(
  "Store Manager" "Customer Support" "Product Expert" "Support Team" "Sales Team"
)

# Sample questions
QUESTIONS=(
  "What is the warranty period for this product?"
  "Is this product suitable for outdoor use?"
  "What are the dimensions of this item?"
  "Does this come in different colors?"
  "Is this product water-resistant?"
  "What materials is this made from?"
  "Can this be used by beginners?"
  "How long does shipping take?"
  "Is this compatible with other products?"
  "What is the return policy for this item?"
  "Does this product require assembly?"
  "Is this item in stock?"
  "What is the weight of this product?"
  "Are there any special care instructions?"
  "Is this product eco-friendly?"
  "Can I customize this product?"
  "What is included in the package?"
  "Is this suitable for children?"
  "Does this come with instructions?"
  "What is the recommended age for this product?"
)

# Sample answers
ANSWERS=(
  "This product comes with a 1-year warranty from the date of purchase."
  "Yes, this product is designed for both indoor and outdoor use."
  "The dimensions are listed in the product description above."
  "Yes, we offer this product in multiple color options."
  "Yes, this product is water-resistant but not waterproof."
  "This product is made from high-quality, durable materials."
  "Absolutely! This product is suitable for all skill levels."
  "Standard shipping typically takes 5-7 business days."
  "Yes, this product is compatible with most standard accessories."
  "We offer a 30-day return policy for all products."
  "Some assembly is required. Instructions are included."
  "Yes, this item is currently in stock and ready to ship."
  "The product weight is approximately 2-3 lbs."
  "Please refer to the care instructions included with the product."
  "Yes, we use eco-friendly materials whenever possible."
  "Unfortunately, customization is not available for this product."
  "The package includes the main product and all necessary accessories."
  "Yes, this product is safe for children aged 3 and above."
  "Yes, detailed instructions are included in the package."
  "This product is recommended for ages 5 and up."
)

# Write Q&A CSV headers
echo "question_id,question_content,question_date,asker_email,asker_name,product_id,product_handle,curated,source,answer_id,answer_content,answerer_email,answerer_name,answer_date" > "$OUTPUT_FILE"

# Fetch product IDs and handles (first 100 products)
PRODUCTS=$(curl -s -u "$CONSUMER_KEY:$CONSUMER_SECRET" \
    "$WC_URL/wp-json/wc/v3/products?per_page=100" | jq -r '.[] | [.id, .slug] | @csv')

QUESTION_COUNTER=1

# Loop through each product
while IFS=, read -r PRODUCT_ID PRODUCT_HANDLE; do
    PRODUCT_HANDLE=$(echo "$PRODUCT_HANDLE" | tr -d '"')
    echo "Generating fake Q&A for product ID $PRODUCT_ID..."

    for i in $(seq 1 $QUESTIONS_PER_PRODUCT); do
        QUESTION_ID=$QUESTION_COUNTER
        ASKER_NAME=${ASKER_NAMES[$RANDOM % ${#ASKER_NAMES[@]}]}
        ASKER_EMAIL="$(echo "$ASKER_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '.')$RANDOM@example.com"

        # Randomly set some emails as anonymous (20% chance)
        if (( RANDOM % 5 == 0 )); then
            ASKER_EMAIL="support+anonymous@judge.me"
        fi

        QUESTION=${QUESTIONS[$RANDOM % ${#QUESTIONS[@]}]}
        QUESTION_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

        # Randomly set curated field: ok, spam, or empty
        RAND_CURATED=$((RANDOM % 10))
        if (( RAND_CURATED < 7 )); then
            CURATED="ok"
        elif (( RAND_CURATED < 9 )); then
            CURATED="spam"
        else
            CURATED=""
        fi

        SOURCE="direct"


        # Randomly add answer (70% chance)
        if (( RANDOM % 10 >= 3 )); then
            ANSWER_ID=$((QUESTION_COUNTER + 10000))
            ANSWERER_NAME=${ANSWERER_NAMES[$RANDOM % ${#ANSWERER_NAMES[@]}]}
            ANSWERER_EMAIL="support@store.com"
            ANSWER=${ANSWERS[$RANDOM % ${#ANSWERS[@]}]}

            # Answer date should be after question date (use same format)
            ANSWER_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
        else
            ANSWER_ID=""
            ANSWERER_NAME=""
            ANSWERER_EMAIL=""
            ANSWER=""
            ANSWER_DATE=""
        fi

        # Append to CSV
        echo "\"$QUESTION_ID\",\"$QUESTION\",\"$QUESTION_DATE\",\"$ASKER_EMAIL\",\"$ASKER_NAME\",$PRODUCT_ID,\"$PRODUCT_HANDLE\",\"$CURATED\",\"$SOURCE\",\"$ANSWER_ID\",\"$ANSWER\",\"$ANSWERER_EMAIL\",\"$ANSWERER_NAME\",\"$ANSWER_DATE\"" >> "$OUTPUT_FILE"

        QUESTION_COUNTER=$((QUESTION_COUNTER + 1))
    done
done <<< "$PRODUCTS"

echo "✅ Fake Judge.me Q&A CSV generated at $OUTPUT_FILE"
echo "📊 Total questions generated: $((QUESTION_COUNTER - 1))"
