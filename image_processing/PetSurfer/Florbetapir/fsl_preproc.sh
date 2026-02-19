#!/bin/bash
#Getsubject ID from env variable
SUBJECT_ID="$1"
RADIOTRACER="$2"

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/subjects"
SUBJECT_LIST_FILE="/data/fbp_subject_list.txt"
export SUBJECTS_DIR="$SUBJECTS_BASE_DIR"
SUBJECTS_PET_DIR="/data/${RADIOTRACER}/subjects"
OUTPUT_DIR="/data/${RADIOTRACER}/subjects/${SUBJECT_ID}/preprocessed"

mkdir -p "$OUTPUT_DIR"

# Generate SUB_ID_NO_E by removing the underscore and everything after it
SUB_ID_NO_E="${SUBJECT_ID%%_*}"



# Echo the job information
echo "Task ID: $SLURM_ARRAY_TASK_ID"
echo "Subject ID: $SUBJECT_ID"
echo "Subject ID without event flag: $SUB_ID_NO_E"
echo "Running in Apptainer container"

if [ -f "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/fbp/image.nii.gz" ]; then
    INPUT_FILE="${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/fbp/image.nii.gz"
elif [ -f "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/fbb/image.nii.gz" ]; then
    INPUT_FILE="${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/fbb/image.nii.gz"
else
    echo "Error: No FBP or FBB image found for subject $SUBJECT_ID"
    exit 1    
fi

# Motion correct and save as image_mcf.nii.gz
mcflirt -in "$INPUT_FILE" -out "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf.nii.gz" -report -plots -stats -meanvol -mats -rmsrel -rmsabs

fslmaths "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf.nii.gz" -Tmean "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf_mean.nii.gz"