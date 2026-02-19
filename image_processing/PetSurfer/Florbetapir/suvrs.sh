#!/bin/bash

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/processed_mri/subjects"
SUBJECT_LIST_FILE="/data/fbp_subject_list.txt"
SUBJECTS_PET_DIR="/data/fbp/subjects"


# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID="$1"

# Extract the subject ID without the event flag (_eX)
sub_no_ev="${SUBJECT_ID%%_e*}"

if [ -z "$2" ]; then
    echo "Error: RADIOTRACER not provided"
    exit 1
fi

RADIOTRACER="$2"

echo "Calculating Basal Ganglia ROI for: $SUBJECT_ID"
echo "Subject ID without event flag: $sub_no_ev"

# Generate the basal ganglia ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg_long.mgz" \
--match 11 12 13 50 51 52 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/basal_ganglia_full.nii.gz"

# Match bounding box to RBV output
mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/basal_ganglia_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc_wm_rr.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/basal_ganglia.nii.gz"

# Clean up temporary file
rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/basal_ganglia_full.nii.gz"



#calculate the suvr for Basal Ganglia
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/basal_ganglia.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc_wm_rr.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/basal_ganglia_stats.txt"


