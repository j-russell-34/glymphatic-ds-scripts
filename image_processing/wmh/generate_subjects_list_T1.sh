#!/bin/bash

STUDY="ABCDS_controls"

# Set up the directory and file paths
SUBJECTS_BASE_DIR="/project2/jasonkru_1564/studies/${STUDY}/subjects_dti/OUTPUTS"
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/samseg_subject_list_T1.txt"

# Check if subjects directory exists
if [ ! -d "$SUBJECTS_BASE_DIR" ]; then
    echo "Error: Subjects directory not found: $SUBJECTS_BASE_DIR"
    exit 1
fi

# Generate the subject list, including only subjects that start with a 5-digit identifier and are followed by _e and anything else
echo "Generating subject list from: $SUBJECTS_BASE_DIR"
ls -1 "$SUBJECTS_BASE_DIR" | grep -E '^[0-9]{5}(_e[0-9].*)?$' > "$SUBJECT_LIST_FILE"

# Remove any empty lines or hidden files
sed -i '/^$/d;/^\./d' "$SUBJECT_LIST_FILE"

#remove any subjects that are in samseg_subject_list.txt
if [ -f "/project2/jasonkru_1564/studies/${STUDY}/samseg_subject_list.txt" ]; then
    echo "Removing subjects that are already in samseg_subject_list.txt"
    grep -v -f "/project2/jasonkru_1564/studies/${STUDY}/samseg_subject_list.txt" "$SUBJECT_LIST_FILE" > "${SUBJECT_LIST_FILE}.tmp"
    mv "${SUBJECT_LIST_FILE}.tmp" "$SUBJECT_LIST_FILE"
fi

# Count and display the number of subjects
NUM_SUBJECTS=$(wc -l < "$SUBJECT_LIST_FILE")
echo "Found $NUM_SUBJECTS subjects"
echo "Subject list saved to: $SUBJECT_LIST_FILE" 