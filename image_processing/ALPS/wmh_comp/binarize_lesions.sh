#!/bin/bash

#get the subject id
subject_id=$1
flair_dir=/data/subjects_FLAIR/OUTPUTS/${subject_id}/samsegOutput
alps_dir=/data/subjects_dti/OUTPUTS/${subject_id}/alps_output
manual_rois=/data/OUTPUTS/${subject_id}/alps_output/manual_rois
default_rois=/data/scripts/ROIs_JHU_ALPS/all_rois.nii.gz

#if T1.mgz and T1.nii.gz is not in flair dir, then cp
if [ ! -f ${flair_dir}/T1.mgz ] && [ ! -f ${flair_dir}/T1.nii.gz ]; then
    echo "T1.mgz and T1.nii.gz not found in FLAIR directory for subject ${subject_id}. Copying from subjects directory."
    cp /data/processed_mri/subjects/${subject_id}/mri/T1.mgz ${flair_dir}/T1.mgz
fi

#generate the lesion mask
#if seg.mgz exists, binarize it
if [ -f ${flair_dir}/seg.mgz ]; then
    mri_binarize \
    --i ${flair_dir}/seg.mgz \
    --match 99 \
    --o ${alps_dir}/wmh_lesion_mask.nii.gz
else
    echo "Error: seg.mgz not found for subject ${subject_id}"
    echo "Using synthseg output instead"
    mri_binarize \
    --i ${flair_dir}/synthseg.nii.gz \
    --match 77 \
    --o ${alps_dir}/wmh_lesion_mask.nii.gz
fi

#convert t1 from mgz to nifti
if [ -f ${flair_dir}/T1.mgz ]; then
    mri_convert \
    ${flair_dir}/T1.mgz \
    ${flair_dir}/T1.nii.gz
else
    echo "Error: T1.mgz not found for subject ${subject_id}"
fi
