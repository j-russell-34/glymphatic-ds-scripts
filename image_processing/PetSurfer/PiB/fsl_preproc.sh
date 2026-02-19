#!/bin/bash
#Get Subject_id from passed variable
SUBJECT_ID="$1"
RADIOTRACER="$2"

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/subjects"
SUBJECT_LIST_FILE="/data/pib_subject_list.txt"
export SUBJECTS_DIR="$SUBJECTS_BASE_DIR"
OUTPUT_DIR="/data/pib/subjects/${SUBJECT_ID}/preprocessed"
SUBJECTS_PET_DIR="/data/pib/subjects"

#make output directory
mkdir -p "${OUTPUT_DIR}"


# Generate SUB_ID_NO_E by removing the underscore and everything after it
SUB_ID_NO_E="${SUBJECT_ID%%_*}"

# Echo the job information
echo "Task ID: $SLURM_ARRAY_TASK_ID"
echo "Subject ID: $SUBJECT_ID"
echo "Subject ID without event flag: $SUB_ID_NO_E"
echo "Running in Apptainer container"

# Motion correct and save as image_mcf.nii.gz
echo "Running mcflirt"
mcflirt -in "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/pib/image.nii.gz" -out "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf.nii.gz" -report -plots -stats -meanvol -mats -rmsrel -rmsabs

fslmaths "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf.nii.gz" -Tmean "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf_mean.nii.gz"