#!/bin/bash

# Directory to save cleaned files
cleaned_dir="phenotypes_clean"
mkdir -p $cleaned_dir

# Iterate over each CSV file matching the pattern
for file in phenotypes/conditions_*.csv; do
  echo "Processing $file..."
  
  # Call the Python script and pass the file path as an argument
  python3 process_file.py "$file"
done

echo "Processing completed."

