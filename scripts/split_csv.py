#!/usr/bin/env python3
import csv
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

input_file = os.path.join(
    BASE_DIR,
    "nutrix_final.csv",
)
output_dir = os.path.join(BASE_DIR, "..", "reviews", "nutrix")
chunk_size = 850

# Read the CSV file
with open(input_file, "r", encoding="utf-8") as f:
    reader = csv.reader(f)
    header = next(reader)  # Get the header row

    chunk_num = 1
    chunk_data = []
    start_row = 1

    for i, row in enumerate(reader, 1):
        chunk_data.append(row)

        # When we reach chunk_size, write the chunk
        if len(chunk_data) == chunk_size:
            end_row = start_row + len(chunk_data) - 1

            # Create filename with range
            output_file = os.path.join(output_dir, f"{start_row}-{end_row}-reviews.csv")

            # Write chunk to file
            with open(output_file, "w", encoding="utf-8", newline="") as out_f:
                writer = csv.writer(out_f)
                writer.writerow(header)  # Write header
                writer.writerows(chunk_data)  # Write data

            print(f"Created: {output_file} ({len(chunk_data)} entries)")

            # Reset for next chunk
            start_row = end_row + 1
            chunk_data = []
            chunk_num += 1

    # Write any remaining data in the last chunk
    if chunk_data:
        end_row = start_row + len(chunk_data) - 1

        output_file = os.path.join(output_dir, f"{start_row}-{end_row}-reviews.csv")

        with open(output_file, "w", encoding="utf-8", newline="") as out_f:
            writer = csv.writer(out_f)
            writer.writerow(header)
            writer.writerows(chunk_data)

        print(f"Created: {output_file} ({len(chunk_data)} entries)")
        chunk_num += 1

print(f"\nTotal files created: {chunk_num - 1}")
