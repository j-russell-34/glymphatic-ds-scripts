#!/bin/bash

#concat all basal ganglia stats into single csv
OUTPUT_CSV="/project2/jasonkru_1564/studies/ABCDS/OUTPUT/fbp_basal_ganglia.csv"
mkdir -p "$(dirname "$OUTPUT_CSV")"
echo "Subject_ID,Basal_Ganglia_SUVR" > "$OUTPUT_CSV"

#iterate through subjects stats files adding subject_id from directory path and basal ganglia suvr value
SUBJECTS_PET_DIR="/project2/jasonkru_1564/studies/ABCDS/fbp/subjects"
while IFS= read -r -d '' SUBJECT_DIR; do
    SUBJECT_ID=$(basename "$SUBJECT_DIR")
    STATS_FILE="${SUBJECTS_PET_DIR}/${SUBJECT_ID}/basal_ganglia_stats.txt"
    if [ -f "$STATS_FILE" ]; then
        BASAL_GANGLIA_SUVR=$(head -n 1 "$STATS_FILE")
        echo "${SUBJECT_ID},${BASAL_GANGLIA_SUVR}" >> "$OUTPUT_CSV"
    else
        echo "Warning: Stats file not found for subject $SUBJECT_ID"
    fi
done < <(find "$SUBJECTS_PET_DIR" -mindepth 1 -maxdepth 1 -type d -print0)
echo "Basal ganglia SUVR stats concatenated into $OUTPUT_CSV"

