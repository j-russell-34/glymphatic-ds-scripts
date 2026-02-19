#!/bin/bash
set -euo pipefail

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/tractoflow/tractoflow_output"
SUBJECTS_FW_DIR="/data/freewater_flow/freewater_flow_output"
SUBJECT=$1

#generate choroid plexus roi
INPUT_WMPARC="${SUBJECTS_BASE_DIR}/${SUBJECT}/Register_Freesurfer/${SUBJECT}__wmparc_warped.nii.gz"
if [ ! -f "$INPUT_WMPARC" ]; then
  echo "Error: Input file $INPUT_WMPARC does not exist."
  exit 1
fi

mri_binarize \
--i "$INPUT_WMPARC" \
--match 31 63 \
--o ${SUBJECTS_BASE_DIR}/${SUBJECT}/Register_Freesurfer/brain_choroid_plexus_roi.nii.gz

# Check if the free water image exists
FW_IMAGE="${SUBJECTS_FW_DIR}/${SUBJECT}/Compute_FreeWater/${SUBJECT}__FW.nii.gz"
if [ ! -f "$FW_IMAGE" ]; then
  echo "Error: Free water image $FW_IMAGE does not exist."
  exit 1
fi

#calculate free water in choroid plexus
mri_segstats \
--seg ${SUBJECTS_BASE_DIR}/${SUBJECT}/Register_Freesurfer/brain_choroid_plexus_roi.nii.gz \
--id 1 \
--i "$FW_IMAGE" \
--avgwf ${SUBJECTS_FW_DIR}/${SUBJECT}/Compute_FreeWater/${SUBJECT}_choroid_plexus_FW.txt
