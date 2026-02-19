#!/bin/bash

# Check if SLURM_ARRAY_TASK_ID is set
if [ -z "$SLURM_ARRAY_TASK_ID" ]; then
    echo "Error: SLURM_ARRAY_TASK_ID is not set"
    exit 1
fi

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/processed_mri/subjects"
SUBJECT_LIST_FILE="/data/cblm_subject_list.txt"
export SUBJECTS_DIR="$SUBJECTS_BASE_DIR"

# Source FreeSurfer configuration (should be in the container)
source $FREESURFER_HOME/SetUpFreeSurfer.sh

# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

# Echo the job information
echo "Task ID: $SLURM_ARRAY_TASK_ID"
echo "Subject ID: $SUBJECT_ID"
echo "Subject Directory: $SUBJECTS_DIR/$SUBJECT_ID"
echo "Running in Apptainer container"

mkdir -p /data/tau_inf_cereb_grey/subjects/$SUBJECT_ID/mri/orig

#binarise cerebellar grey matter
mri_binarize --i $SUBJECTS_DIR/$SUBJECT_ID/mri/aseg.mgz --match 8 47 --o /data/tau_inf_cereb_grey/subjects/$SUBJECT_ID/mri/cerebellar_gm_mask.nii.gz

#move conformed image to ras in orig
mri_convert --out_orientation RAS $SUBJECTS_DIR/$SUBJECT_ID/mri/orig.mgz /data/tau_inf_cereb_grey/subjects/$SUBJECT_ID/mri/orig/image_ras.nii
