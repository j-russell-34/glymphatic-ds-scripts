#!/bin/bash

# Check if the subject ID argument is provided
if [ $# -lt 1 ]; then
    echo "Error: Missing subject ID argument"
    echo "Usage: $0 <subject_id>"
    exit 1
fi

# Store the subject ID from the command line argument
SUBJECT_ID="$1"
TRACER="$2"

# Validate that SUBJECT_ID is not empty
if [ -z "$SUBJECT_ID" ]; then
    echo "Error: SUBJECT_ID is empty"
    exit 1
fi

echo "Running FSL preprocessing for subject: $SUBJECT_ID"

# Preprocess PET
bash /data/scripts/fsl_preproc.sh ${SUBJECT_ID} ${TRACER}

echo "Completed FSL preprocessing for subject: $SUBJECT_ID"

# Calculate ratios
python /data/scripts/suvr_spm.py ${SUBJECT_ID} ${TRACER}

echo "Completed SUVR calculation for subject: $SUBJECT_ID"

