#!/bin/sh

# WC_URL="https://mercyyuko.in"
# CONSUMER_KEY="ck_45af9141bd0a1452dc8217900192c43d751932a1"
# CONSUMER_SECRET="cs_10d35d0df9700dc8266b660af0954d5f3e033996"

WC_URL="https://benitto-backend.ngrok.dev"
CONSUMER_KEY="ck_ead77cb8a57897aa348edff4011d1e59ae315282"
CONSUMER_SECRET="cs_ac01f7592c5a9508db1ea6572d62b063592860ca"

# # Endpoints with flags ("endpoint|true/false")
# ENDPOINTS="
# /wp-json/wc/v3/products/reviews?status=all|true
# /wp-json/wc/v3/products|true
# /wp-json/wc/v3/orders|true
# /wp-json/wc/v3/customers|true
# /wp-json/wc/v3/webhooks|true
# /wp-json/wc/v3/yuko/getStoreData|true
# "
#
ENDPOINTS="
/wp-json/wc/v3/orders|true
/wp-json/wc/v3/customers|true
"

print_headers_table() {
    endpoint="$1"
    headers="$2"

    # Extract status line (first line of headers)
    status_line=$(echo "$headers" | head -n 1)
    status_code=$(echo "$status_line" | awk '{print $2}')

    # Color highlight based on status
    if [ "$status_code" -ge 200 ] && [ "$status_code" -lt 300 ]; then
        status_display="✅ $status_code"
    else
        status_display="❌ $status_code"
    fi

    echo ""
    echo "=== Headers for $endpoint ==="
    echo "Response Status: $status_display ($status_line)"
    printf "%-25s | %s\n" "Header" "Value"
    printf "%-25s-+-%s\n" "-------------------------" "-----------------------------------------"

    echo "$headers" | tail -n +2 | while IFS=":" read -r key value; do
        if [ -n "$key" ] && [ -n "$value" ]; then
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            printf "%-25s | %s\n" "$key" "$value"
        fi
    done
    echo ""
}

# Loop endpoints
echo "$ENDPOINTS" | while IFS="|" read -r endpoint flag; do
    if [ "$flag" = "true" ]; then
        # Generate OAuth-signed URL using PHP
        signed_url=$(php -r "
        \$url = '$WC_URL$endpoint';
        \$ck = '$CONSUMER_KEY';
        \$cs = '$CONSUMER_SECRET';

        // OAuth parameters
        \$params = [
            'oauth_consumer_key' => \$ck,
            'oauth_nonce' => bin2hex(random_bytes(16)),
            'oauth_signature_method' => 'HMAC-SHA1',
            'oauth_timestamp' => time(),
            'oauth_version' => '1.0',
        ];

        // Sort parameters
        ksort(\$params);

        // Build base string (RFC3986 encoding for spaces)
        \$base_string = 'GET&' . rawurlencode(\$url) . '&' . rawurlencode(http_build_query(\$params, '', '&', PHP_QUERY_RFC3986));

        // Generate signature
        \$signature = base64_encode(hash_hmac('sha1', \$base_string, rawurlencode(\$cs) . '&', true));

        // Add signature to parameters
        \$params['oauth_signature'] = \$signature;

        // Output signed URL
        echo \$url . '?' . http_build_query(\$params, '', '&', PHP_QUERY_RFC3986);
        ")

        # Call WooCommerce endpoint and fetch headers
        response=$(curl -s -I "$signed_url")

        # Print response headers
        print_headers_table "$endpoint" "$response"
    fi
done

# # Loop endpoints
# echo "$ENDPOINTS" | while IFS="|" read -r endpoint flag; do
#     if [ "$flag" = "true" ]; then
#         response=$(curl -s -I -u "$CONSUMER_KEY:$CONSUMER_SECRET" "$WC_URL$endpoint")
#         print_headers_table "$endpoint" "$response"
#     fi
# done

