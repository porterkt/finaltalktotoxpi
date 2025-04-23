#CSV File of State Data at the Tract Level was downloaded from the EJScreen website (https://www.epa.gov/ejscreen/download-ejscreen-data), downloaded under the name EJScreen_2024_Tract_StatePct_with_AS_CNMI_GU_VI.csv
import pandas as pd
import os

input_csv = '/Users/porterkt/finaltalktotoxpi/EJScreen_2024_Tract_StatePct_with_AS_CNMI_GU_VI.csv'

#Output directory for county CSV files
output_dir = '/Users/porterkt/finaltalktotoxpi/RAG_data/counties'
os.makedirs(output_dir, exist_ok=True)

#Get csv file into dataframe form
df = pd.read_csv(input_csv)

#Check that required columns exist
if 'CNTY_NAME' not in df.columns or 'STATE_NAME' not in df.columns:
    raise ValueError("The required columns 'CNTY_NAME' or 'STATE_NAME' do not exist in the CSV file. Please check the column names.")

#Columns with an update needed
columns_to_update = df.columns[172:222]

#Function to delete the last five characters in specified columns
def delete_last_five_characters(dataframe, column_indices):
    for col in column_indices:
        dataframe[col] = dataframe[col].astype(str).str[:-5]
    return dataframe

#Group by the 'CNTY_NAME' and 'STATE' columns and save each group to a separate CSV file
for (state_name, county_name), county_df in df.groupby(['STATE_NAME', 'CNTY_NAME']):
    # Delete the last five characters in the specified columns
    county_df = delete_last_five_characters(county_df, columns_to_update)
    
    #Generate a safe filename by replacing any unsafe characters
    safe_county_name = "".join([c if c.isalnum() else "_" for c in county_name])
    safe_state_name = "".join([c if c.isalnum() else "_" for c in state_name])
    output_path = os.path.join(output_dir, f"{safe_state_name}_{safe_county_name}.csv")
    
    county_df.to_csv(output_path, index=False)
    print(f"Saved {output_path}")

print("Done splitting CSV file by county and state.")


#Paths to the EJ Screen Data and county data directory
ej_screen_excel = '/Users/porterkt/finaltalktotoxpi/EJScreen_2024_Tract_Percentiles_Columns.xlsx'
county_data_dir = '/Users/porterkt/finaltalktotoxpi/RAG_data/counties'

#Load the EJ Screen Data from the Excel file without headers
ej_screen_df = pd.read_excel(ej_screen_excel, header=None)
import pandas as pd

#Load the EJ Screen data from the Excel file
ej_screen_excel = '/Users/porterkt/finaltalktotoxpi/EJScreen_2024_Tract_Percentiles_Columns.xlsx'
ej_screen_df = pd.read_excel(ej_screen_excel, header=None)

#Ensure the third column exists
if ej_screen_df.shape[1] <= 2:
    raise ValueError("The EJ Screen data doesn't contain enough columns. Please check the file.")

#Extract the third column starting from the 3rd row, converting it to a list
df = ej_screen_df.iloc[2:, 2].values.tolist()
df.pop(1)
column_names = df

#Create the output directory if it doesn't exist
os.makedirs(county_data_dir, exist_ok=True)

#Loop through each county file in the directory
for filename in os.listdir(county_data_dir):
    if filename.endswith('.csv'):
        file_path = os.path.join(county_data_dir, filename)
        
        #Load each county dataset
        county_df = pd.read_csv(file_path)
        
        #Ensure the number of columns matches the number of names
        if county_df.shape[1] != len(column_names):
            print(f"Column count mismatch for file {filename}. Skipping this file.")
            continue
        
        #Update the column names
        county_df.columns = column_names
        
        #Save the modified dataset back to the same file
        county_df.to_csv(file_path, index=False)
        print(f"Updated column names for {file_path}")

print("Done updating column names for all county datasets.")

#Define the input directory and output directory
counties_directory = '/Users/porterkt/finaltalktotoxpi/RAG_data/counties'
output_directory = '/Users/porterkt/talktotoxpi/RAG_data/cleaned_counties'
os.makedirs(output_directory, exist_ok=True)

# Columns to be deleted
columns_to_delete = [
    "Shape area", "Shape length", "Land area in square meters", "Water area in square meters"
]

# Iterate through each CSV file in the directory
for filename in os.listdir(counties_directory):
    if filename.endswith('.csv'):
        # Full path of the CSV file
        filepath = os.path.join(counties_directory, filename)
        
        # Read the CSV file into a DataFrame
        df = pd.read_csv(filepath)
        
        # Delete specific columns
        df = df.drop(columns=columns_to_delete, errors='ignore')
        
        # Drop columns starting with "Map color bin" or "Map popup text"
        df = df.loc[:, ~df.columns.str.startswith(('Map color bin', 'Map popup text'))]

        # Generate output path and save the cleaned DataFrame
        output_path = os.path.join(output_directory, filename)
        df.to_csv(output_path, index=False)
        print(f"Saved cleaned file: {output_path}")

print("Completed cleaning all county CSV files.")

import numpy as np

#Directory containing the cleaned county CSV files
cleaned_counties_dir = '/Users/porterkt/finaltalktotoxpi/RAG_data/cleaned_counties'
output_combined_dir = '/Users/porterkt/finaltalktotoxpi/RAG_data/combined_counties'

#Create the output directory if it doesn't exist
os.makedirs(output_combined_dir, exist_ok=True)

#Function to process and combine rows in each dataset
def process_county_file(file_path, output_path):
    #Read the CSV file into a DataFrame
    df = pd.read_csv(file_path)

    #Keep the first 6 columns of the first row only, set them as the first row
    first_6_columns = df.iloc[0, :6]
    df.iloc[1:, :6] = np.nan

    #Average the columns that contain "%" or "index"
    cols_to_average = [col for col in df.columns if "%" in col or "index" in col.lower()]
    averaged_columns = df[cols_to_average].mean()

    #Sum the remaining columns excluding the first 6 columns and the average columns
    remaining_columns = df.columns.difference(first_6_columns.index.tolist() + cols_to_average)
    summed_columns = df[remaining_columns].sum(numeric_only=True)

    #Combine the averaged and summed results into one row
    combined_result = pd.concat([first_6_columns, averaged_columns, summed_columns])

    #Convert to DataFrame
    combined_df = pd.DataFrame([combined_result])

    #Save the combined generalized row to a new CSV file
    combined_df.to_csv(output_path, index=False)
    print(f"Saved combined file: {output_path}")

#Loop through each CSV file in the input directory
for filename in os.listdir(cleaned_counties_dir):
    if filename.endswith('.csv'):
        input_file_path = os.path.join(cleaned_counties_dir, filename)
        output_file_path = os.path.join(output_combined_dir, filename)
        process_county_file(input_file_path, output_file_path)

print("Processing completed for all files.")

#Define the input directory and output directory
cleaned_counties_directory = '/Users/porterkt/finaltalktotoxpi/RAG_data/combined_counties'
output_directory = '/Users/porterkt/finaltalktotoxpi/RAG_data/txt_counties'
os.makedirs(output_directory, exist_ok=True)

#Function that converts a DataFrame row to a formatted string
def row_to_txt_string(row):
    census_fips = row['Census FIPS code for tract']
    row_data = [f"{col}: {row[col]}" for col in row.index if col != 'Census FIPS code for tract']
    return f"Census FIPS: {census_fips}, " + ', '.join(row_data)

#Iterate through each cleaned CSV file in the directory
for filename in os.listdir(cleaned_counties_directory):
    if filename.endswith('.csv'):
        #Full path of the CSV file
        filepath = os.path.join(cleaned_counties_directory, filename)
        
        #Read the CSV file into a DataFrame
        df = pd.read_csv(filepath)

        #Convert each row in the DataFrame to the desired TXT string format
        text_lines = [row_to_txt_string(row) for _, row in df.iterrows()]
        
        #Generate output path for the TXT file and save
        output_path = os.path.join(output_directory, filename.replace('.csv', '.txt'))
        with open(output_path, 'w') as f_out:
            for line in text_lines:
                f_out.write(line + '\n')
        print(f"Saved TXT file: {output_path}")

print("Completed converting all cleaned county CSV files to TXT format.")