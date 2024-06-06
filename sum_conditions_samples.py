import pandas as pd
import sys

# Path to the merged data file
merged_file_path = sys.argv[1]

# Read the merged data file
data = pd.read_csv(merged_file_path)

# Calculate the sum of each column
column_sums = data.sum(numeric_only=True).to_dict()

# Save the column sums to a file
column_sums_file_path = sys.argv[2]
with open(column_sums_file_path, 'w') as file:
    for column, sum_value in column_sums.items():
        file.write(f"{column}: {sum_value}\n")

print(f"The sum of each column has been saved to: {column_sums_file_path}")

# Calculate the sum of each row
row_sums = data.set_index('subject_id').sum(axis=1).to_dict()

# Save the row sums to a file
row_sums_file_path = sys.argv[3]
with open(row_sums_file_path, 'w') as file:
    for subject_id, sum_value in row_sums.items():
        file.write(f"{subject_id}: {sum_value}\n")

print(f"The sum of each row has been saved to: {row_sums_file_path}")

