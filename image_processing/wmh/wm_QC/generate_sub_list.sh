#!/bin/bash

#Study specific variables
STUDY="ABCDS"

# Set up the directory and file paths
SUBJECTS_BASE_DIR="/project2/jasonkru_1564/studies/${STUDY}/subjects_FLAIR/OUTPUTS"
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/flair_list_qc.txt"
PROCESSED_SUBJECTS="/project2/jasonkru_1564/studies/${STUDY}/OUTPUT/QC_FLAIR/WMH/"
SUBJECT_FILE_LIST_TEMP="/project2/jasonkru_1564/studies/${STUDY}/flair_list_qc_temp.txt"

# Check if subjects directory exists
if [ ! -d "$SUBJECTS_BASE_DIR" ]; then
    echo "Error: Subjects directory not found: $SUBJECTS_BASE_DIR"
    exit 1
fi

# Generate the subject list, including directories that start with XXXXX_eX
echo "Generating subject list from: $SUBJECTS_BASE_DIR"
ls -1 "$SUBJECTS_BASE_DIR" | grep -E '^[0-9]{5}_e[0-9]' > "$SUBJECT_LIST_FILE"

#generate list of subjects already processed
PROCESSED_SUBJECTS_FILE="/project2/jasonkru_1564/studies/${STUDY}/OUTPUT/QC_FLAIR/processed_subjects.txt"
#if pdf exists for subect in form xxxxx_eX_report.pdf, add xxxxx_eX to processed_subjects.txt
find "$PROCESSED_SUBJECTS" -mindepth 1 -maxdepth 1 -type f -name '*_report.pdf' | \
    sed -E 's/.*\/([0-9]{5}_e[0-9])_report\.pdf/\1/' > "$PROCESSED_SUBJECTS_FILE"

# Remove any empty lines
sed -i '/^$/d' "$SUBJECT_LIST_FILE"

#remove subjects that have already been processed
grep -v -F -f "$PROCESSED_SUBJECTS_FILE" "$SUBJECT_LIST_FILE" > "$SUBJECT_FILE_LIST_TEMP"

# Move the temporary file to the final subject list file
mv "$SUBJECT_FILE_LIST_TEMP" "$SUBJECT_LIST_FILE"

# Count and display the number of subjects
NUM_SUBJECTS=$(wc -l < "$SUBJECT_LIST_FILE")
echo "Found $NUM_SUBJECTS subjects to process"
echo "Subject list saved to: $SUBJECT_LIST_FILE" 