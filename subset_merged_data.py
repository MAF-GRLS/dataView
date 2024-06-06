import pandas as pd
import sys

# Path to the merged data file
merged_file_path = sys.argv[1] 

# Path to the column sums file
column_sums_file_path = sys.argv[2]

# Read the column names from the column sums file
with open(column_sums_file_path, 'r') as file:
    columns = [line.split(':')[0].strip() for line in file]

# Read the merged data file
data = pd.read_csv(merged_file_path)

# Ensure 'subject_id' is included in the subset
if 'subject_id' not in columns:
    columns.insert(0, 'subject_id')

# Subset the dataframe to include only the specified columns
subset_data = data[columns]

# Save the subset dataframe to a new CSV file
subset_file_path = sys.argv[3]
subset_data.to_csv(subset_file_path, index=False)

print(f"The subset data has been saved to: {subset_file_path}")

