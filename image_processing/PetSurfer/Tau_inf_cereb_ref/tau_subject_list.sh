#!/bin/bash

#Study specific variables
STUDY="ABCDS"

# Set up the directory and file paths
SUBJECTS_BASE_DIR="/project2/jasonkru_1564/studies/${STUDY}/subjects"
TAU_CEREB_DIR="/project2/jasonkru_1564/studies/${STUDY}/tau_inf_cereb_grey/subjects"
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/tau_subject_list.txt"

# Check if subjects directory exists
if [ ! -d "$SUBJECTS_BASE_DIR" ]; then
    echo "Error: Subjects directory not found: $SUBJECTS_BASE_DIR"
    exit 1
fi

# Check if tau_inf_cereb_grey directory exists
if [ ! -d "$TAU_CEREB_DIR" ]; then
    echo "Error: Tau inferior cerebellar grey directory not found: $TAU_CEREB_DIR"
    exit 1
fi

# Create a temporary file
TEMP_LIST=$(mktemp)

# Generate initial subject list from SUBJECTS_BASE_DIR that have ftp or mk6240 subdirectories (unprocessed tau images)
find "$SUBJECTS_BASE_DIR" -mindepth 2 -maxdepth 2 -type d \( -name "ftp" -o -name "mk6240" \) ! -path "*/fsaverage/*" \
| sed 's|/ftp$||' \
| sed 's|/mk6240$||' \
| sed "s|$SUBJECTS_BASE_DIR/||" \
> "$TEMP_LIST"

# Filter subjects - must have both unprocessed tau images AND reference regions, but NOT already processed
> "$SUBJECT_LIST_FILE"  # Clear the output file
while IFS= read -r subject; do
    # Check if subject has reference region in TAU_CEREB_DIR
    if [ ! -d "$TAU_CEREB_DIR/$subject" ]; then
        echo "Skipping $subject - no reference region found in tau_inf_cereb_grey"
        continue
    fi
    
    # Check if subject already has processed tau data (ftp or mk6240 subdirectories in TAU_CEREB_DIR)
    if [ -d "$TAU_CEREB_DIR/$subject/ftp" ] || [ -d "$TAU_CEREB_DIR/$subject/mk6240" ]; then
        echo "Skipping $subject - already has processed tau data (ftp or mk6240 subdirectory)"
    else
        echo "$subject" >> "$SUBJECT_LIST_FILE"
    fi
done < "$TEMP_LIST"

# Clean up temporary file
rm "$TEMP_LIST"

# Remove any empty lines or hidden files
sed -i '/^$/d;/^\./d' "$SUBJECT_LIST_FILE"

# Count and display the number of subjects
NUM_SUBJECTS=$(wc -l < "$SUBJECT_LIST_FILE")
echo "Found $NUM_SUBJECTS subjects with unprocessed tau images, reference regions, and needing tau processing"
echo "Subject list saved to: $SUBJECT_LIST_FILE" 