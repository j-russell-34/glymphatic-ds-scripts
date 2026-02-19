#!/bin/bash

#Study specific variables
STUDY="ABCDS_controls"

# Copy code to temporary directory
mkdir -p /home1/jasonkru/temp_code/
cp -r /home1/jasonkru/atri_code/processors/alps-main /home1/jasonkru/temp_code/

# Path to the subject list file
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/subject_list_alps_qc.txt"

# Check if the subject list file exists
if [ ! -f "$SUBJECT_LIST_FILE" ]; then
    echo "Error: Subject list file not found at $SUBJECT_LIST_FILE"
    exit 1
fi

# Count the number of subjects in the file
SUBJECT_COUNT=$(grep -v "^$" "$SUBJECT_LIST_FILE" | wc -l)

if [ "$SUBJECT_COUNT" -eq 0 ]; then
    echo "Error: No subjects found in $SUBJECT_LIST_FILE"
    exit 1
fi

echo "Found $SUBJECT_COUNT subjects in the subject list file."

# Path to the SLURM script
SLURM_SCRIPT="slurm_array_alps_man.sh"

# Check if the SLURM script exists
if [ ! -f "$SLURM_SCRIPT" ]; then
    echo "Error: SLURM script not found at $SLURM_SCRIPT"
    exit 1
fi

# Create a temporary copy of the SLURM script
TMP_SCRIPT=$(mktemp)
cp "$SLURM_SCRIPT" "$TMP_SCRIPT"

# Set the array range based on the subject count
# If more than 80 subjects, limit concurrent jobs to 80
if [ "$SUBJECT_COUNT" -gt 80 ]; then
    echo "More than 80 subjects detected. Limiting concurrent jobs to 80."
    sed -i "s/^#SBATCH --array=.*/#SBATCH --array=1-$SUBJECT_COUNT%80/" "$TMP_SCRIPT"
else
    sed -i "s/^#SBATCH --array=.*/#SBATCH --array=1-$SUBJECT_COUNT/" "$TMP_SCRIPT"
fi

echo "Submitting SLURM array job with array range 1-$SUBJECT_COUNT"

# Submit the job
sbatch "$TMP_SCRIPT"

# Clean up the temporary script
rm "$TMP_SCRIPT"

echo "Job submitted. Check the queue with 'squeue -u $USER'"