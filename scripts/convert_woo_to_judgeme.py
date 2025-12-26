#!/usr/bin/env python3
"""
Convert WooCommerce reviews CSV to Judge.me format
"""

import csv
from datetime import datetime

# Input and output file paths
input_file = 'woocommerce_reviews.csv'
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
output_file = f'judgeme_reviews_{timestamp}.csv'

# Judge.me CSV headers
judgeme_headers = [
    'title',
    'body',
    'rating',
    'review_date',
    'source',
    'curated',
    'reviewer_name',
    'reviewer_email',
    'product_id',
    'product_handle',
    'reply',
    'reply_date',
    'picture_urls',
    'ip_address',
    'location'
]

# Column mapping from WooCommerce to Judge.me
# woocommerce_field -> judgeme_field
column_mapping = {
    'body': 'body',
    'author': 'reviewer_name',
    'email': 'reviewer_email',
    'date': 'review_date',
    'product_id': 'product_id',
    'product_handle': 'product_handle',
    'review_score': 'rating'
}

print(f"Converting {input_file} to Judge.me format...")

# Read WooCommerce CSV and write Judge.me CSV
with open(input_file, 'r', encoding='utf-8') as infile, \
     open(output_file, 'w', encoding='utf-8', newline='') as outfile:

    reader = csv.DictReader(infile)
    writer = csv.DictWriter(outfile, fieldnames=judgeme_headers)

    # Write headers
    writer.writeheader()

    # Convert each row
    row_count = 0
    for woo_row in reader:
        judgeme_row = {
            'title': '',  # Empty as per requirements
            'body': woo_row.get('body', ''),
            'rating': woo_row.get('review_score', ''),
            'review_date': woo_row.get('date', ''),
            'source': 'WooCommerce',  # Constant value
            'curated': 'ok',  # Set to 'ok' by default
            'reviewer_name': woo_row.get('author', ''),
            'reviewer_email': woo_row.get('email', ''),
            'product_id': woo_row.get('product_id', ''),
            'product_handle': woo_row.get('product_handle', ''),
            'reply': '',  # Empty
            'reply_date': '',  # Empty
            'picture_urls': '',  # Empty
            'ip_address': '',  # Empty
            'location': ''  # Empty
        }

        writer.writerow(judgeme_row)
        row_count += 1

    print(f"✅ Conversion complete!")
    print(f"   Converted {row_count} reviews")
    print(f"   Output file: {output_file}")
