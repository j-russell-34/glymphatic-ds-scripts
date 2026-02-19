#!/bin/bash

#Study specific variables
STUDY="ABCDS"
RADIOTRACER="ftp"

# Set up the directory and file paths
SUBJECTS_BASE_DIR="/project2/jasonkru_1564/studies/${STUDY}/subjects"
PROCESSED_MRI_DIR="/project2/jasonkru_1564/studies/${STUDY}/processed_mri/subjects"
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/cblm_subject_list.txt"
INFERIOR_CEREBELLUM_DIR="/project2/jasonkru_1564/studies/${STUDY}/tau_inf_cereb_grey/subjects"

# Check if subjects directory exists
if [ ! -d "$SUBJECTS_BASE_DIR" ]; then
    echo "Error: Subjects directory not found: $SUBJECTS_BASE_DIR"
    exit 1
fi

# Check if processed_mri directory exists
if [ ! -d "$PROCESSED_MRI_DIR" ]; then
    echo "Error: Processed MRI directory not found: $PROCESSED_MRI_DIR"
    exit 1
fi

# Create a temporary file
TEMP_LIST=$(mktemp)

# Generate initial subject list
find "$SUBJECTS_BASE_DIR" -mindepth 2 -maxdepth 2 -type d -name "$RADIOTRACER" ! -path "*/fsaverage/*" \
| sed "s|/$RADIOTRACER\$||" \
| sed "s|$SUBJECTS_BASE_DIR/||" \
> "$TEMP_LIST"

# Filter subjects based on existence in processed_mri directory
> "$SUBJECT_LIST_FILE"  # Clear the output file
while IFS= read -r subject; do
    if [ -d "$PROCESSED_MRI_DIR/$subject" ]; then
        echo "$subject" >> "$SUBJECT_LIST_FILE"
    else
        echo "Skipping $subject - not found in processed_mri"
    fi
done < "$TEMP_LIST"

# Remove subjects who are already in /tau_inf_cereb_grey/subjects/ dir
# Create a new temporary file for the filtered list
FILTERED_LIST=$(mktemp)

while IFS= read -r subject; do
    if [ -d "$INFERIOR_CEREBELLUM_DIR/$subject" ]; then
        echo "Removing $subject - already processed in tau_inf_cereb_grey"
    else
        echo "$subject" >> "$FILTERED_LIST"
    fi
done < "$SUBJECT_LIST_FILE"

# Replace the subject list file with the filtered version
mv "$FILTERED_LIST" "$SUBJECT_LIST_FILE"

# Clean up temporary file
rm "$TEMP_LIST"

# Remove any empty lines or hidden files
sed -i '/^$/d;/^\./d' "$SUBJECT_LIST_FILE"

# Count and display the number of subjects
NUM_SUBJECTS=$(wc -l < "$SUBJECT_LIST_FILE")
echo "Found $NUM_SUBJECTS subjects with both PET and processed MRI data"
echo "Subject list saved to: $SUBJECT_LIST_FILE" 