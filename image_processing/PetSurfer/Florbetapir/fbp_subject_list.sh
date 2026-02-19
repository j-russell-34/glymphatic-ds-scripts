#!/bin/bash

#Study specific variables
STUDY="ABCDS"


# Set up the directory and file paths
SUBJECTS_BASE_DIR="/project2/jasonkru_1564/studies/${STUDY}/subjects"
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/fbp_subject_list.txt"

# Check if subjects directory exists
if [ ! -d "$SUBJECTS_BASE_DIR" ]; then
    echo "Error: Subjects directory not found: $SUBJECTS_BASE_DIR"
    exit 1
fi

# Generate the subject list, including only those with a 'fbp' subfolder
echo "Generating subject list from: $SUBJECTS_BASE_DIR"

# Find all directories that match the pattern *.long* and have an fbp or fbb subdirectory
find "$SUBJECTS_BASE_DIR" -mindepth 2 -maxdepth 2 -type d \( -name "fbp" -o -name "fbb" \) ! -path "*/fsaverage/*" | sed -E 's@/(fbp|fbb)$@@' | sed "s|$SUBJECTS_BASE_DIR/||" > "$SUBJECT_LIST_FILE"


# Remove any empty lines or hidden files
sed -i '/^$/d;/^\./d' "$SUBJECT_LIST_FILE"

# Count and display the number of subjects
NUM_SUBJECTS=$(wc -l < "$SUBJECT_LIST_FILE")
echo "Found $NUM_SUBJECTS subjects"
echo "Subject list saved to: $SUBJECT_LIST_FILE" 