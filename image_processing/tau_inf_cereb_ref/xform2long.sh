#!/bin/bash

# Check if SLURM_ARRAY_TASK_ID is set
if [ -z "$SLURM_ARRAY_TASK_ID" ]; then
    echo "Error: SLURM_ARRAY_TASK_ID is not set"
    exit 1
fi

# Check if SUB_ID_NO_E is set
if [ -z "$2" ]; then
    echo "Error: SUB_ID_NO_E is not set"
    exit 1
fi

SUB_ID_NO_E="$2"

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/tau_inf_cereb_grey/subjects"
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
echo "Long Directory: $SUBJECTS_DIR/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base"

#convert inf mask to mgz
mri_convert $SUBJECTS_DIR/${SUBJECT_ID}/mri/final_inferior_cerebellar_mask.nii.gz $SUBJECTS_DIR/${SUBJECT_ID}/mri/inferior_cerebellum.mgz

#COMMENT OUT IF NOT RUNNING IN LONGITUDINAL SPACE
mri_vol2vol \
--mov $SUBJECTS_DIR/${SUBJECT_ID}/mri/inferior_cerebellum.mgz \
--targ /data/processed_mri/subjects/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/orig.mgz \
--lta /data/processed_mri/subjects/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta \
--o /data/processed_mri/subjects/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/inferior_cerebellum.mgz
