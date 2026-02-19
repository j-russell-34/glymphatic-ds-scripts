#!/bin/bash

# Check if SLURM_ARRAY_TASK_ID is set
if [ -z "$SLURM_ARRAY_TASK_ID" ]; then
    echo "Error: SLURM_ARRAY_TASK_ID is not set"
    exit 1
fi

# Check if RADIOTRACER is provided
if [ -z "$2" ]; then
    echo "Error: RADIOTRACER not provided"
    exit 1
fi

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/subjects"
SUBJECT_LIST_FILE="/data/tau_subject_list.txt"
RADIOTRACER="$2"
export SUBJECTS_DIR="$SUBJECTS_BASE_DIR"

# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

# Generate SUB_ID_NO_E by removing the underscore and everything after it
SUB_ID_NO_E="${SUBJECT_ID%%_*}"

# Echo the job information
echo "Task ID: $SLURM_ARRAY_TASK_ID"
echo "Subject ID: $SUBJECT_ID"
echo "Subject ID without event flag: $SUB_ID_NO_E"
echo "RADIOTRACER: $RADIOTRACER"
echo "Running in Apptainer container"

mkdir -p /data/tau_inf_cereb_grey/subjects/${SUBJECT_ID}/${RADIOTRACER}

# Motion correct and save as tau_mcf.nii.gz
echo "Running mcflirt"
mcflirt -in "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/${RADIOTRACER}/image.nii.gz" -out "/data/tau_inf_cereb_grey/subjects/${SUBJECT_ID}/${RADIOTRACER}/image_mcf.nii.gz" -report -plots -stats -meanvol -mats -rmsrel -rmsabs

fslmaths "/data/tau_inf_cereb_grey/subjects/${SUBJECT_ID}/${RADIOTRACER}/image_mcf.nii.gz" -Tmean "/data/tau_inf_cereb_grey/subjects/${SUBJECT_ID}/${RADIOTRACER}/image_mcf_mean.nii.gz"