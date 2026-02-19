# Run post processing for FreeSurfer 7 recon-all

SUBJECT_ID=$1

# Create necessary directories
mkdir -p "/data/OUTPUT/QC_FLAIR/WMH"

# Make script executable
chmod +x /data/scripts/make_pdf.sh

#cp T1 to FLAIR directory
# if T1 is is present copy else look in excl_subs
if [ -f "/data/processed_mri/subjects/${SUBJECT_ID}/mri/T1.mgz" ]; then
    cp "/data/processed_mri/subjects/${SUBJECT_ID}/mri/T1.mgz" "/data/subjects_FLAIR/OUTPUTS/${SUBJECT_ID}/samsegOutput"
else
    echo "T1.mgz not found for subject ${SUBJECT_ID}. Checking excl_subs."
    if [ -f "/data/excl_subs/${SUBJECT_ID}/mri/T1.mgz" ]; then
        cp "/data/excl_subs/${SUBJECT_ID}/mri/T1.mgz" "/data/subjects_FLAIR/OUTPUTS/${SUBJECT_ID}/samsegOutput"
    else
        echo "T1.mgz not found for subject ${SUBJECT_ID} in excl_subs. Skipping."
        exit 1
    fi
fi

# Create QA PDF
cd /data/subjects_FLAIR/OUTPUTS/${SUBJECT_ID}/samsegOutput
xvfb-run -a --server-args "-screen 0 1920x1080x24" /data/scripts/make_pdf.sh

mv /data/subjects_FLAIR/OUTPUTS/${SUBJECT_ID}/samsegOutput/report.pdf /data/OUTPUT/QC_FLAIR/WMH/${SUBJECT_ID}_report.pdf

echo "run DONE!"