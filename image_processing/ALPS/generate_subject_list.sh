#!/bin/bash

#Study specific variables
STUDY="ABCDS_controls"

# Set up the directory and file paths
SUBJECTS_BASE_DIR="/project2/jasonkru_1564/studies/${STUDY}/subjects_dti"
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/subject_list_alps.txt"

# Check if subjects directory exists
if [ ! -d "$SUBJECTS_BASE_DIR" ]; then
    echo "Error: Subjects directory not found: $SUBJECTS_BASE_DIR"
    exit 1
fi

# Generate the subject list, ignoring QA_Reports and fsaverage
echo "Generating subject list from: $SUBJECTS_BASE_DIR"
ls -1 "$SUBJECTS_BASE_DIR" | grep -v -E '^(fsaverage|QA_Reports)$' > "$SUBJECT_LIST_FILE"

# Remove any empty lines or hidden files
sed -i '/^$/d;/^\./d' "$SUBJECT_LIST_FILE"

# Count and display the number of subjects
NUM_SUBJECTS=$(wc -l < "$SUBJECT_LIST_FILE")
echo "Found $NUM_SUBJECTS subjects"
echo "Subject list saved to: $SUBJECT_LIST_FILE" 