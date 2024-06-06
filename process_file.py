import pandas as pd
import os
import sys

# Get the file path from the command line arguments
file_path = sys.argv[1]

# Load the CSV file
data = pd.read_csv(file_path, low_memory=False)

# Filter the dataframe to include only rows where 'to_date' equals 1
data = data[data['to_date'] == 1]

# Group by 'subject_id' and find the row with the maximum 'year_in_study'
data = data.loc[data.groupby('subject_id')['year_in_study'].idxmax()]

# Delete specified columns
columns_to_delete = ['relationship_category', 'year_in_study', 'record_date', 'to_date', 'any']
data = data.drop(columns=[col for col in columns_to_delete if col in data.columns])

# Remove columns where all values are 0 or NA
data = data.loc[:, (data != 0).any(axis=0)]
data = data.dropna(axis=1, how='all')

# Delete 'other_specify' if it exists
if 'other_specify' in data.columns:
        data = data.drop(columns=['other_specify'])
        print("other_specify was force deleted")


# Extract the name of the tissue from the file path
prefix = os.path.basename(file_path).split('_')[1].split('.')[0]

# Add the prefix to all column names except 'subject_id'
data = data.rename(
            columns={col: f"{prefix}_{col}" for col in data.columns if col != 'subject_id'}
            )

# Print the sum of all columns except 'subject_id'
print(f"Sum of all columns except 'subject_id' for {file_path}:")
print(data.drop(columns=['subject_id']).sum())

# Create the cleaned file path
cleaned_file_path = f'phenotypes_clean/{os.path.basename(file_path)}'

# Save the cleaned dataframe to the new CSV file
data.to_csv(cleaned_file_path, index=False)

print(f"The cleaned data has been saved to: {cleaned_file_path}")

