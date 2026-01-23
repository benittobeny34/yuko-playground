#!/usr/bin/env bash

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# JudgeMe header format
JUDGEME_HEADERS=(
    'title'
    'body'
    'rating'
    'review_date'
    'source'
    'curated'
    'reviewer_name'
    'reviewer_email'
    'product_id'
    'product_handle'
    'reply'
    'reply_date'
    'picture_urls'
    'ip_address'
    'location'
)

# Check if fzf is installed
if ! command -v fzf &> /dev/null; then
    echo -e "${RED}Error: fzf is not installed or not in PATH${NC}"
    echo "Please install fzf: brew install fzf"
    exit 1
fi

# Check if CSV file is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide a CSV file as argument${NC}"
    echo "Usage: $0 <csv_file>"
    exit 1
fi

INPUT_FILE="$1"

# Check if file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: File '$INPUT_FILE' not found${NC}"
    exit 1
fi

echo -e "${GREEN}=== CSV to JudgeMe Header Mapper ===${NC}\n"

# Ask for platform
echo -e "${BLUE}Select platform:${NC}"
echo "1. WooCommerce (default)"
echo "2. Shopify"
read -p "Enter choice (1 or 2, press Enter for WooCommerce): " platform_choice

PLATFORM="woocommerce"
if [ "$platform_choice" = "2" ]; then
    PLATFORM="shopify"
    # Add metaobject_handle for Shopify
    JUDGEME_HEADERS+=('metaobject_handle')
fi

echo -e "${GREEN}Platform selected: $PLATFORM${NC}\n"

# Read the first line (headers) from CSV using Python for proper CSV parsing
INPUT_HEADERS_STR=$(python3 -c "
import csv
import sys

# Handle BOM and encoding issues
with open('$INPUT_FILE', 'r', encoding='utf-8-sig') as f:
    reader = csv.reader(f)
    headers = next(reader)
    for h in headers:
        # Strip whitespace and clean header
        cleaned = h.strip()
        print(cleaned)
")

# Convert to array (compatible with older bash)
INPUT_HEADERS=()
while IFS= read -r line; do
    INPUT_HEADERS+=("$line")
done <<< "$INPUT_HEADERS_STR"

# Debug: Check if headers were loaded
if [ ${#INPUT_HEADERS[@]} -eq 0 ] || [ -z "${INPUT_HEADERS[0]}" ]; then
    echo -e "${RED}Error: Failed to read headers from CSV file${NC}"
    echo "Debugging info:"
    echo "First line of file:"
    head -n 1 "$INPUT_FILE"
    exit 1
fi

# Show source headers
echo -e "${YELLOW}Found ${#INPUT_HEADERS[@]} headers in source CSV:${NC}"
for i in "${!INPUT_HEADERS[@]}"; do
    # Skip empty headers
    if [ -n "${INPUT_HEADERS[$i]}" ]; then
        echo "$((i+1)). ${INPUT_HEADERS[$i]}"
    fi
done
echo ""

# Arrays to store new header names
declare -a NEW_HEADERS

# Initialize with original headers
for i in "${!INPUT_HEADERS[@]}"; do
    NEW_HEADERS[$i]="${INPUT_HEADERS[$i]}"
done

# Track which source headers have been mapped
declare -a MAPPED_HEADERS
for i in "${!INPUT_HEADERS[@]}"; do
    MAPPED_HEADERS[$i]=0
done

# Map each JudgeMe header to source header(s)
for j in "${!JUDGEME_HEADERS[@]}"; do
    judgeme_header="${JUDGEME_HEADERS[$j]}"

    echo -e "${CYAN}=== Mapping JudgeMe header $((j+1))/${#JUDGEME_HEADERS[@]}: '${judgeme_header}' ===${NC}"
    echo -e "${YELLOW}Select source column(s) to rename (TAB for multi-select, ENTER to confirm, ESC to skip)${NC}\n"

    # Create fzf options with index numbers
    fzf_options=""
    for i in "${!INPUT_HEADERS[@]}"; do
        if [ "${MAPPED_HEADERS[$i]}" -eq 1 ]; then
            fzf_options+="$((i+1)). ${INPUT_HEADERS[$i]} ${CYAN}[already mapped to: ${NEW_HEADERS[$i]}]${NC}\n"
        else
            fzf_options+="$((i+1)). ${INPUT_HEADERS[$i]}\n"
        fi
    done

    # Use fzf for selection (multi-select enabled)
    selected=$(echo -e "$fzf_options" | fzf \
        --ansi \
        --multi \
        --prompt="Map to '$judgeme_header' > " \
        --header="TAB: select/deselect | ENTER: confirm | ESC: skip this field" \
        --height=50% \
        --border \
        --reverse)

    if [ -z "$selected" ]; then
        echo -e "${RED}Skipping '${judgeme_header}' (no mapping)${NC}\n"
    else
        # Extract indices from selected lines
        selected_indices=()
        while IFS= read -r line; do
            # Extract number before the dot
            idx=$(echo "$line" | grep -o '^[0-9]\+' | head -1)
            if [ -n "$idx" ]; then
                # Convert to 0-based index
                selected_indices+=($((idx - 1)))
            fi
        done <<< "$selected"

        # If only one column selected, rename it directly
        if [ ${#selected_indices[@]} -eq 1 ]; then
            idx=${selected_indices[0]}
            NEW_HEADERS[$idx]="$judgeme_header"
            MAPPED_HEADERS[$idx]=1
            echo -e "${GREEN}'${INPUT_HEADERS[$idx]}' renamed to '${judgeme_header}'${NC}\n"
        else
            # Multiple columns selected - rename first one, add suffix to others
            for i in "${!selected_indices[@]}"; do
                idx=${selected_indices[$i]}
                if [ $i -eq 0 ]; then
                    NEW_HEADERS[$idx]="$judgeme_header"
                    echo -e "${GREEN}'${INPUT_HEADERS[$idx]}' renamed to '${judgeme_header}'${NC}"
                else
                    NEW_HEADERS[$idx]="${judgeme_header}_part_$((i+1))"
                    echo -e "${GREEN}'${INPUT_HEADERS[$idx]}' renamed to '${judgeme_header}_part_$((i+1))'${NC}"
                fi
                MAPPED_HEADERS[$idx]=1
            done
            echo -e "${YELLOW}Note: You'll need to manually combine these columns${NC}\n"
        fi
    fi
done

# Show mapping confirmation table
echo -e "\n${YELLOW}=== HEADER MAPPING CONFIRMATION ===${NC}\n"
echo -e "${BLUE}┌────────────────────────────────────┬────────────────────────────────────┐${NC}"
printf "${BLUE}│${NC} %-34s ${BLUE}│${NC} %-34s ${BLUE}│${NC}\n" "Original Header" "New Header"
echo -e "${BLUE}├────────────────────────────────────┼────────────────────────────────────┤${NC}"

for i in "${!INPUT_HEADERS[@]}"; do
    orig_h="${INPUT_HEADERS[$i]}"
    new_h="${NEW_HEADERS[$i]}"

    # Truncate if too long
    if [ ${#orig_h} -gt 34 ]; then
        orig_h="${orig_h:0:31}..."
    fi
    if [ ${#new_h} -gt 34 ]; then
        new_h="${new_h:0:31}..."
    fi

    if [ "${INPUT_HEADERS[$i]}" = "${NEW_HEADERS[$i]}" ]; then
        # Unchanged - will be manually removed
        printf "${BLUE}│${NC} %-34s ${BLUE}│${NC} ${RED}%-34s${NC} ${BLUE}│${NC}\n" "$orig_h" "$new_h (unchanged)"
    else
        # Mapped
        printf "${BLUE}│${NC} %-34s ${BLUE}│${NC} ${GREEN}%-34s${NC} ${BLUE}│${NC}\n" "$orig_h" "$new_h"
    fi
done

echo -e "${BLUE}└────────────────────────────────────┴────────────────────────────────────┘${NC}\n"

echo -e "${YELLOW}Unmapped columns (to be manually removed):${NC}"
unmapped_count=0
for i in "${!INPUT_HEADERS[@]}"; do
    if [ "${MAPPED_HEADERS[$i]}" -eq 0 ]; then
        echo -e "${RED}  - ${INPUT_HEADERS[$i]}${NC}"
        ((unmapped_count++))
    fi
done

if [ $unmapped_count -eq 0 ]; then
    echo -e "${GREEN}  None - all columns are mapped${NC}"
fi
echo ""

# Ask for confirmation
read -p "Proceed with header replacement? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Operation cancelled.${NC}"
    exit 0
fi

# Generate output filename
OUTPUT_FILE="${INPUT_FILE%.csv}_judgeme.csv"

echo -e "${YELLOW}Creating output file with new headers...${NC}"

# Write new headers using Python for proper CSV handling
python3 << 'PYTHON_SCRIPT' "$OUTPUT_FILE" "${NEW_HEADERS[@]}"
import csv
import sys

output_file = sys.argv[1]
new_headers = sys.argv[2:]

# Read original file
with open('INPUT_FILE_PLACEHOLDER', 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    next(reader)  # Skip original headers
    data_rows = list(reader)

# Write new file with updated headers
with open(output_file, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(new_headers)
    writer.writerows(data_rows)

print(f"✓ File created: {output_file}")
PYTHON_SCRIPT

# Replace placeholder with actual input file
sed -i.bak "s|INPUT_FILE_PLACEHOLDER|$INPUT_FILE|g" /tmp/csv_converter_$$.py 2>/dev/null || true

# Actually run Python to convert
python3 -c "
import csv
import sys

output_file = '$OUTPUT_FILE'
new_headers = ['${NEW_HEADERS[0]}'$(printf ', "%s"' "${NEW_HEADERS[@]:1}")]

# Read original file (handle BOM)
with open('$INPUT_FILE', 'r', encoding='utf-8-sig') as f:
    reader = csv.reader(f)
    next(reader)  # Skip original headers
    data_rows = list(reader)

# Write new file with updated headers
with open(output_file, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(new_headers)
    writer.writerows(data_rows)
"

echo -e "${GREEN}✓ Conversion complete!${NC}"
echo -e "${GREEN}✓ Output file: $OUTPUT_FILE${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. Open the file and manually delete unmapped columns"
echo -e "  2. Combine any multi-part columns (e.g., reviewer_name_part_2)"
echo -e "  3. Fill in any required empty JudgeMe fields"
