#!/bin/bash

#get the subject id from the command line
SUBJECT_ID=$1
STUDY_DIR=/data

#Set up the paths to the input files
t1=$STUDY_DIR/subjects/$SUBJECT_ID/mri/orig/image.nii.gz
flair=$STUDY_DIR/subjects_FLAIR/$SUBJECT_ID/image.nii.gz
flair_coreg=$STUDY_DIR/subjects_FLAIR/OUTPUTS/$SUBJECT_ID/flair_coreg.nii.gz
samseg_output=$STUDY_DIR/subjects_FLAIR/OUTPUTS/$SUBJECT_ID/samsegOutput

mkdir -p $STUDY_DIR/subjects_FLAIR/OUTPUTS/$SUBJECT_ID

#coregister the T2 to the T1
mri_coreg \
    --mov $flair \
    --ref $t1 \
    --reg $STUDY_DIR/subjects_FLAIR/OUTPUTS/$SUBJECT_ID/flairtot1.lta

mri_vol2vol \
    --mov $flair \
    --reg flairtot1.lta \
    --o $flair_coreg \
    --targ $t1 

#segment using samseg with --lesion
run_samseg \
    --input $t1 $flair_coreg \
    --pallidum-separate \
    --lesion \
    --lesion-mask-pattern 0 1 \
    --output $samseg_output \
    --threads 8

