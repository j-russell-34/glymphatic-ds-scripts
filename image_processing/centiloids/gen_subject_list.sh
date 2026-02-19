#!/bin/bash

# Define the STUDY and TRACER variables
STUDY="ABCDS" 
TRACER="fbp"  

# Define the output file name
output_file="/project2/jasonkru_1564/studies/${STUDY}/centiloid_${TRACER}_subject_list.txt"

# Create the output directory if it doesn't exist
output_dir=$(dirname "$output_file")
mkdir -p "$output_dir"

# Initialize the subjects list file
> "$output_file"  # Clear the file if it exists

# Iterate through each subject directory
for subject_dir in /project2/jasonkru_1564/studies/${STUDY}/subjects/*/; do
    # Check if the TRACER directory exists
    if [ -d "${subject_dir}/${TRACER}" ]; then
        # Get the subject name (directory name)
        subject_name=$(basename "$subject_dir")
        # Add the subject name to the subjects list file
        echo "$subject_name" >> "$output_file"
    fi
done

echo "Subject list created: $output_file"