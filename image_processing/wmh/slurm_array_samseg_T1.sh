#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=gpu
#SBATCH --gres=gpu:a100:1
#SBATCH --job-name=fs_synthseg
#SBATCH --array=1-4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --output=logs/synthseg_%A_%a.log

STUDY="ABCDS_controls"

# Check if subject list exists
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/samseg_subject_list_T1.txt"
if [ ! -f "$SUBJECT_LIST_FILE" ]; then
    echo "Error: Subject list not found. Please run generate_subjects_list_T1.sh first"
    exit 1
fi

#load module
module purge
module load apptainer

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up Singularity environment
CONTAINER="/project2/jasonkru_1564/containers/mri_WMHsynthseg/wmh_synthseg_latest.sif"

# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo "Error: Apptainer container not found at $CONTAINER"
    exit 1
fi

# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

STUDY_DIR=/data

#Set up the paths to the input files
t1=$STUDY_DIR/subjects/$SUBJECT_ID/mri/orig/image.nii.gz
samseg_output=$STUDY_DIR/subjects_FLAIR/OUTPUTS/$SUBJECT_ID/samsegOutput

# Create output directory on the HOST side (before container runs)
mkdir -p /project2/jasonkru_1564/studies/${STUDY}/subjects_FLAIR/OUTPUTS/$SUBJECT_ID/samsegOutput

# Call the processing script with the current array task ID using Apptainer
apptainer exec --nv \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    "$CONTAINER" \
    python /app/WMHSynthSeg/inference.py \
    --i "$t1" \
    --o "$samseg_output/synthseg.nii.gz" \
    --device cuda \
    --crop

