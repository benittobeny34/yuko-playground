#!/usr/bin/env python3
"""
Script to rearrange CSV headers in a specific order.
Headers not in the predefined list will be appended at the end.
"""

import csv
import sys
import re
from pathlib import Path


def to_snake_case(text):
    """
    Convert a string to snake_case.
    Handles spaces, hyphens, and camelCase.
    """
    # Replace spaces and hyphens with underscores
    text = text.strip().replace(" ", "_").replace("-", "_")
    # Insert underscore before uppercase letters and convert to lowercase
    text = re.sub("(.)([A-Z][a-z]+)", r"\1_\2", text)
    text = re.sub("([a-z0-9])([A-Z])", r"\1_\2", text)
    # Replace multiple underscores with single underscore
    text = re.sub("_+", "_", text)
    return text.lower()


def rearrange_csv_headers(input_file, output_file=None):
    """
    Rearrange CSV headers according to the specified order.

    Args:
        input_file: Path to the input CSV file
        output_file: Path to the output CSV file (optional, defaults to input_file_reordered.csv)
    """
    # Define the desired header order
    desired_order = [
        "title",
        "body",
        "rating",
        "review_date",
        "source",
        "curated",
        "reviewer_name",
        "reviewer_email",
        "product_id",
        "product_handle",
        "reply",
        "reply_date",
        "picture_urls",
        "ip_address",
        "location",
        "metaobject_handle",
    ]

    # Read the input CSV
    try:
        with open(input_file, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            original_headers = reader.fieldnames
            rows = list(reader)
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)

    if not original_headers:
        print("Error: CSV file has no headers.")
        sys.exit(1)

    # Create a mapping from snake_case to original header names
    snake_to_original = {to_snake_case(h): h for h in original_headers}

    # Create new header order
    # First add headers from desired_order that exist in the original file (matched by snake_case)
    new_headers = []
    matched_originals = set()

    for desired_header in desired_order:
        desired_snake = to_snake_case(desired_header)
        if desired_snake in snake_to_original:
            original_header = snake_to_original[desired_snake]
            new_headers.append(
                to_snake_case(original_header)
            )  # Convert to lowercase snake_case
            matched_originals.add(original_header)

    # Then add any remaining headers that weren't matched (also convert to lowercase snake_case)
    remaining_headers = [
        to_snake_case(h) for h in original_headers if h not in matched_originals
    ]
    new_headers.extend(remaining_headers)

    # Convert row data from original headers to snake_case headers
    converted_rows = []
    for row in rows:
        new_row = {to_snake_case(key): value for key, value in row.items()}
        converted_rows.append(new_row)

    # Set output file name if not provided
    if output_file is None:
        input_path = Path(input_file)
        output_file = (
            input_path.parent / f"{input_path.stem}_reordered{input_path.suffix}"
        )

    # Write the reordered CSV
    try:
        with open(output_file, "w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=new_headers)
            writer.writeheader()
            writer.writerows(converted_rows)

        print(f"✓ Successfully reordered CSV headers")
        print(f"  Input:  {input_file}")
        print(f"  Output: {output_file}")
        print(f"\nOriginal headers: {len(original_headers)}")
        print(f"New headers:      {len(new_headers)}")

        if remaining_headers:
            print(f"\nHeaders appended at the end (not in predefined order):")
            for h in remaining_headers:
                print(f"  - {h}")
    except Exception as e:
        print(f"Error writing file: {e}")
        sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print(
            "Usage: python3 rearrange_csv_headers.py <input_file.csv> [output_file.csv]"
        )
        print("\nExample:")
        print("  python3 rearrange_csv_headers.py reviews.csv")
        print("  python3 rearrange_csv_headers.py reviews.csv reviews_reordered.csv")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    rearrange_csv_headers(input_file, output_file)


if __name__ == "__main__":
    main()
