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

# Check if PSF_CSV is provided
if [ -z "$3" ]; then
    echo "Error: PSF_CSV not provided"
    exit 1
fi

RADIOTRACER="$2"
PSF_CSV="$3"

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/processed_mri/subjects"
SUBJECT_LIST_FILE="/data/tau_subject_list.txt"
SUBJECTS_PET_DIR="/data/tau_inf_cereb_grey/subjects"
#set subject directory
export SUBJECTS_DIR="$SUBJECTS_BASE_DIR"

#check if ${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER} exists, delete it
if [ -d "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}" ]; then
    rm -rf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}"
fi

# Source FreeSurfer setup
source $FREESURFER_HOME/SetUpFreeSurfer.sh

# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

# Extract the PSF values from the ABCDS_filters.csv file
ABCDS_FILTERS_FILE="$PSF_CSV"

# Debug: Print what we're looking for
echo "DEBUG: Looking for subject ID: '$SUBJECT_ID'"
echo "DEBUG: Looking for radiotracer: '$RADIOTRACER'"
echo "DEBUG: CSV file: '$ABCDS_FILTERS_FILE'"

read PSFCOL PSFROW PSFSLICE <<< $(awk -F ',' -v sid="$SUBJECT_ID" -v tracer="$RADIOTRACER" '
    NR==1 {
        for (i=1; i<=NF; i++) {
            # Clean the column name of ^M characters before comparison
            col_name = $i
            gsub(/\r$/, "", col_name)
            if (col_name=="fsid") fsid_col=i
            if (col_name=="filterxy") filterxy_col=i
            if (col_name=="filterz") filterz_col=i
            if (col_name=="radiotracer") radiotracer_col=i
        }
        print "DEBUG: Column positions - fsid:" fsid_col ", filterxy:" filterxy_col ", filterz:" filterz_col ", radiotracer:" radiotracer_col > "/dev/stderr"
        print "DEBUG: First line columns:" $0 > "/dev/stderr"
        
        # Check if all required columns were found
        if (fsid_col == "" || filterxy_col == "" || filterz_col == "" || radiotracer_col == "") {
            print "ERROR: Missing required columns. Found - fsid:" fsid_col ", filterxy:" filterxy_col ", filterz:" filterz_col ", radiotracer:" radiotracer_col > "/dev/stderr"
            exit 1
        }
    }
    NR>1 && (gsub(/\r$/, "", $fsid_col) && $fsid_col==sid) && (tolower($radiotracer_col)==tolower(tracer)) {
        print "DEBUG: Found match at line" NR " - fsid:" $fsid_col ", radiotracer:" $radiotracer_col > "/dev/stderr"
        print "DEBUG: Match line columns:" $0 > "/dev/stderr"
        print $filterxy_col, $filterxy_col, $filterz_col
        exit
    }

' "$ABCDS_FILTERS_FILE")

if [ -z "$PSFCOL" ] || [ -z "$PSFROW" ] || [ -z "$PSFSLICE" ]; then
    echo "Error: Could not find PSF values for subject $SUBJECT_ID with $RADIOTRACER radiotracer"
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

# First register PET to anatomical
mri_coreg \
--s "${SUBJECT_ID}" \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/image_mcf_mean.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/${RADIOTRACER}.reg.lta" \
--ref "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/nu.mgz" --no-ref-mask

# Convert PET to anatomical space first
mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/image_mcf_mean.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/${RADIOTRACER}.reg.lta" \
--targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/nu.mgz" \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/image_mcf_mean_anat.nii.gz"

mri_coreg \
--s "${SUBJECT_ID}" \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/image_mcf_mean_anat.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/${RADIOTRACER}_1.reg.lta" \
--ref "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/nu.mgz" --no-ref-mask

# Now run gtmpvc with the anatomical space PET
mri_gtmpvc \
--i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/image_mcf_mean_anat.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/${RADIOTRACER}_1.reg.lta" \
--psf-col $PSFCOL \
--psf-row $PSFROW \
--psf-slice $PSFSLICE \
--seg "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg.mgz" \
--default-seg-merge \
--replace 29 24 \
--mgx .01 \
--rescale 8 47 \
--save-input \
--rbv \
--no-reduce-fov \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output"

#mri_coreg \
#--s "${SUBJECT_ID}" \
#--mov "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/input.rescaled.nii.gz" \
#--reg "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/${RADIOTRACER}/${RADIOTRACER}_input.reg.lta" \
#--ref nu.mgz --no-ref-mask

#generate scaled image (noPVC) in MRI space
mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/input.rescaled.nii.gz" \
--lta "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/${RADIOTRACER}_1.reg.lta" \
--targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/nu.mgz" \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/input.rescaled.nii.gz"

#project to fsaverage surface
mri_vol2surf \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/mgx.ctxgm.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/aux/bbpet2anat.lta" \
--hemi lh \
--projfrac 0.5 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/lh.mgx.ctxgm.fsaverage.sm00.nii.gz" \
--cortex \
--trgsubject fsaverage

mri_vol2surf \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/mgx.ctxgm.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/aux/bbpet2anat.lta" \
--hemi rh \
--projfrac 0.5 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/rh.mgx.ctxgm.fsaverage.sm00.nii.gz" \
--cortex \
--trgsubject fsaverage

#transform to long space
#check if the transform file exists
if [ -f "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" ]; then
    echo "Transform file exists. Using it."
    mri_vol2vol \
    --mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/rbv.nii.gz" \
    --lta "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" \
    --targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/nu.mgz" \
    --o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/rbv.long.nii.gz"

    mri_vol2vol \
    --mov "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg.mgz" \
    --lta "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" \
    --targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/nu.mgz" \
    --o "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg_long.mgz"

    mri_vol2vol \
    --mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/input.rescaled.nii.gz" \
    --lta "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" \
    --targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/nu.mgz" \
    --o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/input.rescaled.long.nii.gz"

    cp "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg.ctab" "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg_long.ctab"

else
    cp "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/rbv.nii.gz" "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/rbv.long.nii.gz"
    cp "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg.mgz" "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg_long.mgz"
    cp "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg.ctab" "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg_long.ctab"
    cp "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/input.rescaled.nii.gz" "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc.output/input.rescaled.long.nii.gz"
    echo "Transform file does not exist. skip transforms."
    exit 1
fi


#re-run with inferior cerebellum ref region

mri_vol2vol \
--interp nearest \
--mov $SUBJECTS_PET_DIR/${SUBJECT_ID}/mri/inferior_cerebellum.mgz \
--targ $SUBJECTS_BASE_DIR/${SUBJECT_ID}/mri/gtmseg.mgz \
--o $SUBJECTS_BASE_DIR/${SUBJECT_ID}/mri/inferior_cerebellum_ref.mgz \
--regheader

# Merge with gtmseg
mergeseg \
--src $SUBJECTS_BASE_DIR/${SUBJECT_ID}/mri/gtmseg.mgz \
--merge $SUBJECTS_BASE_DIR/${SUBJECT_ID}/mri/inferior_cerebellum_ref.mgz \
--segid 9999 \
--o $SUBJECTS_BASE_DIR/${SUBJECT_ID}/mri/gtmseg+infcereb.mgz

# Copy the original ctab file
cp $SUBJECTS_BASE_DIR/${SUBJECT_ID}/mri/gtmseg.ctab $SUBJECTS_BASE_DIR/${SUBJECT_ID}/mri/gtmseg+infcereb.ctab

# Add the inferior cerebellum entry with proper formatting (using tabs and spaces to match alignment)
printf "9999  inferior_cerebellum             230 148  34    0   2\n" >> $SUBJECTS_BASE_DIR/${SUBJECT_ID}/mri/gtmseg+infcereb.ctab

cp $SUBJECTS_BASE_DIR/${SUBJECT_ID}/mri/gtmseg.lta $SUBJECTS_BASE_DIR/${SUBJECT_ID}/mri/gtmseg+infcereb.lta


mri_gtmpvc \
--i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/image_mcf_mean_anat.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/${RADIOTRACER}_1.reg.lta" \
--psf-col $PSFCOL \
--psf-row $PSFROW \
--psf-slice $PSFSLICE \
--seg "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb.mgz" \
--default-seg-merge \
--replace 29 24 \
--mgx .01 \
--rescale 9999 \
--save-input \
--rbv \
--no-reduce-fov \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output"


# #mri_coreg \
# --s "${SUBJECT_ID}" \
# --mov "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/input.rescaled.nii.gz" \
# --reg "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/${RADIOTRACER}/${RADIOTRACER}_input.reg.lta" \
# --ref nu.mgz --no-ref-mask

#generate scaled image (noPVC) in MRI space
mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/input.rescaled.nii.gz" \
--lta "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/${RADIOTRACER}_1.reg.lta" \
--targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/nu.mgz" \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/input.rescaled.nii.gz"

#project to fsaverage surface
mri_vol2surf \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/mgx.ctxgm.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/aux/bbpet2anat.lta" \
--hemi lh \
--projfrac 0.5 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/lh.mgx.ctxgm.fsaverage.sm00.nii.gz" \
--cortex \
--trgsubject fsaverage

mri_vol2surf \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/mgx.ctxgm.nii.gz" \
--reg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/aux/bbpet2anat.lta" \
--hemi rh \
--projfrac 0.5 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rh.mgx.ctxgm.fsaverage.sm00.nii.gz" \
--cortex \
--trgsubject fsaverage

#transform to long space
#check if the transform file exists
if [ -f "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" ]; then
    echo "Transform file exists. Using it."
    mri_vol2vol \
    --mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.nii.gz" \
    --lta "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" \
    --targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/nu.mgz" \
    --o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz"

    mri_vol2vol \
    --mov "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb.mgz" \
    --lta "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" \
    --targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/nu.mgz" \
    --o "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz"

    mri_vol2vol \
    --mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/input.rescaled.nii.gz" \
    --lta "${SUBJECTS_BASE_DIR}/${SUB_ID_NO_E}_base/mri/transforms/${SUBJECT_ID}_to_${SUB_ID_NO_E}_base.lta" \
    --targ "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}.long.${SUB_ID_NO_E}_base/mri/nu.mgz" \
    --o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/input.rescaled.long.nii.gz"

    cp "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb.ctab" "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.ctab"

else
    cp "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.nii.gz" "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz"
    cp "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb.mgz" "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz"
    cp "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb.ctab" "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.ctab"
    cp "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/input.rescaled.nii.gz" "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/input.rescaled.long.nii.gz"
    echo "Transform file does not exist. skip transforms."
    exit 1
fi

