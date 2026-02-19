#!/bin/bash

#get the subject id from the command line
SUBJECT_ID=$1
STUDY_DIR=/data

#Set up the paths to the input files
t1=$STUDY_DIR/subjects/$SUBJECT_ID/mri/orig/image.nii.gz
samseg_output=$STUDY_DIR/subjects_FLAIR/OUTPUTS/$SUBJECT_ID/samsegOutput

mkdir -p $STUDY_DIR/subjects_FLAIR/OUTPUTS/$SUBJECT_ID


#segment using samseg with --lesion
mri_WMHsynthseg \
    --input $t1 \
    --output $samseg_output \
    --threads 8

