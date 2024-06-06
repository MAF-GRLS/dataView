import pandas as pd
import os

# Directory containing the cleaned files
cleaned_dir = 'phenotypes_clean'

# List all CSV files in the directory
files = [f for f in os.listdir(cleaned_dir) if f.endswith('.csv')]

# Initialize an empty dataframe
merged_data = pd.DataFrame()

# Iterate over each file and merge them on 'subject_id'
for file in files:
    file_path = os.path.join(cleaned_dir, file)
    data = pd.read_csv(file_path)
    
    if merged_data.empty:
        merged_data = data
    else:
        merged_data = pd.merge(merged_data, data, on='subject_id', how='outer')

# Save the merged dataframe to a new CSV file
merged_file_path = 'phenotypes_clean/merged_data.csv'
merged_data.to_csv(merged_file_path, index=False)

print(f"The merged data has been saved to: {merged_file_path}")

