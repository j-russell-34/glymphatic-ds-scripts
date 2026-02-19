#!/bin/bash
#Getsubject ID from env variable
SUBJECT_ID="$1"
RADIOTRACER="$2"
PSF_CSV="$3"

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/processed_mri/subjects"
SUBJECT_LIST_FILE="/data/pib_subject_list.txt"
export SUBJECTS_DIR="$SUBJECTS_BASE_DIR"
OUTPUT_DIR="/data/${RADIOTRACER}/subjects/${SUBJECT_ID}/preprocessed"
SUBJECTS_PET_DIR="/data/${RADIOTRACER}/subjects"

# Source FreeSurfer setup
source $FREESURFER_HOME/SetUpFreeSurfer.sh


# Extract the PSF values from the ABCDS_filters.csv file
ABCDS_FILTERS_FILE="/data/csvs/ABCDS_filters.csv"
read PSFCOL PSFROW PSFSLICE <<< $(awk -F ',' -v sid="$SUBJECT_ID" -v tracer="PiB" '
    NR==1 {
        for (i=1; i<=NF; i++) {
            col_name = $i
            gsub(/\r$/, "", col_name)
            if (col_name=="fsid") fsid_col=i
            if (col_name=="filterxy") filterxy_col=i
            if (col_name=="filterz") filterz_col=i
            if (col_name=="radiotracer") radiotracer_col=i
        }
    }
    NR>1 && (gsub(/\r$/, "", $fsid_col) && $fsid_col==sid) && (tolower($radiotracer_col)==tolower(tracer)) {
        print $filterxy_col, $filterxy_col, $filterz_col
        exit
    }
' "$ABCDS_FILTERS_FILE")

if [ -z "$PSFCOL" ] || [ -z "$PSFROW" ] || [ -z "$PSFSLICE" ]; then
    echo "Error: Could not find PSF values for subject $SUBJECT_ID with PiB radiotracer"
    exit 1
fi

echo "Using PSF values: PSFCOL=$PSFCOL PSFROW=$PSFROW PSFSLICE=$PSFSLICE"

# Generate SUB_ID_NO_E by removing the underscore and everything after it
SUB_ID_NO_E="${SUBJECT_ID%%_*}"

# Echo the job information
echo "Task ID: $SLURM_ARRAY_TASK_ID"
echo "Subject ID: $SUBJECT_ID"
echo "Subject ID without event flag: $SUB_ID_NO_E"
echo "Running in Apptainer container"

# Define the path to the extracerebral segmentation file
EXTRACEREBRAL_SEG="${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/apas+head.mgz"

# Check if the extracerebral segmentation file exists
if [ -f "$EXTRACEREBRAL_SEG" ]; then
    echo "Using existing extracerebral segmentation."
    gtmseg --s "${SUBJECT_ID}" --no-xcerseg
else
    echo "No existing extracerebral segmentation found. Generating a new one."
    gtmseg --s "${SUBJECT_ID}" --xcerseg
fi

mri_coreg \
--s "${SUBJECT_ID}" \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf_mean.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}.reg.lta" \
--ref "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/nu.mgz" --no-ref-mask

# Convert PET to anatomical space first
mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf_mean.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}.reg.lta" \
--targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/nu.mgz" \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf_mean_anat.nii.gz"

mri_coreg \
--s "${SUBJECT_ID}" \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf_mean_anat.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}_1.reg.lta" \
--ref "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/nu.mgz" --no-ref-mask

# Now run gtmpvc with the anatomical space PET
mri_gtmpvc \
--i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/image_mcf_mean_anat.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}_1.reg.lta" \
--psf-col $PSFCOL \
--psf-row $PSFROW \
--psf-slice $PSFSLICE \
--seg "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg.mgz" \
--default-seg-merge \
--replace 29 24 \
--mgx .01 \
--rescale 7 8 46 47 \
--save-input \
--rbv \
--no-reduce-fov \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output"

# mri_coreg \
# --s "${SUBJECT_ID}.long.${SUB_ID_NO_E}_base" \
# --mov "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/pib/gtmpvc.output/input.rescaled.nii.gz" \
# --reg "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/pib/pib_input.reg.lta" \
# --ref nu.mgz --no-ref-mask


#generate scaled image (noPVC) in MRI space
mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/input.rescaled.nii.gz" \
--lta "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}_1.reg.lta" \
--targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/nu.mgz" \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/input.rescaled.nii.gz"
#project to fsaverage surface
mri_vol2surf \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/mgx.ctxgm.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/aux/bbpet2anat.lta" \
--hemi lh \
--projfrac 0.5 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/lh.mgx.ctxgm.fsaverage.sm00.nii.gz" \
--cortex \
--trgsubject fsaverage

mri_vol2surf \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/mgx.ctxgm.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/aux/bbpet2anat.lta" \
--hemi rh \
--projfrac 0.5 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/rh.mgx.ctxgm.fsaverage.sm00.nii.gz" \
--cortex \
--trgsubject fsaverage

#transform to long space
#check if the transform file exists
if [ -f "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" ]; then
    echo "Transform file exists. Using it."
    mri_vol2vol \
    --mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/rbv.nii.gz" \
    --lta "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" \
    --targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/nu.mgz" \
    --o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/rbv.long.nii.gz"

    mri_vol2vol \
    --mov "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg.mgz" \
    --lta "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" \
    --targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/nu.mgz" \
    --o "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg_long.mgz"

    mri_vol2vol \
    --mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/input.rescaled.nii.gz" \
    --lta "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" \
    --targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/nu.mgz" \
    --o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/input.rescaled.long.nii.gz"

    cp "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg.ctab" "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg_long.ctab"

else
    cp "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/rbv.nii.gz" "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/rbv.long.nii.gz"
    cp "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg.mgz" "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg_long.mgz"
    cp "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg.ctab" "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg_long.ctab"
    cp "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/input.rescaled.nii.gz" "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/gtmpvc.output/input.rescaled.long.nii.gz"
    echo "Transform file does not exist. skip transforms."
    exit 1
fi