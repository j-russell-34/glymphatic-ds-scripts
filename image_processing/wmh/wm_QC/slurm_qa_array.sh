#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=wmh_qc
#SBATCH --array=1-4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4G
#SBATCH --time=0:30:00
#SBATCH --output=logs/wmh_qc_%A_%a.log

#Study specific variables
STUDY="ABCDS"

# Check if subject list exists
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/flair_list_qc.txt"
if [ ! -f "$SUBJECT_LIST_FILE" ]; then
    echo "Error: Subject list not found. Please run generate_subject_list.sh first"
    exit 1
fi

#load module
module purge
module load apptainer

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up Singularity environment
CONTAINER="/scratch1/jasonkru/containers/fs_qa/fs7_post_v1.sif"

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

mkdir -p /project2/jasonkru_1564/studies/${STUDY}/OUTPUT/QC_FLAIR/WMH

tmpxkb="$(mktemp -d)"

# Create a temporary directory for XDG runtime
export XDG_RUNTIME_DIR="/tmp/runtime_${SLURM_JOB_ID}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Call the processing script with the current array task ID using Apptainer
apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/wm_QC:/data/scripts \
    -B /home1/jasonkru/license/fs_license:/license \
    -B "$tmpxkb":/var/lib/xkb \
    -B /tmp/runtime_${SLURM_JOB_ID}:/tmp/runtime_${SLURM_JOB_ID} \
    --env SUBJECTS_DIR="/data/processed_mri/subjects" \
    --env FS_LICENSE="/license/license.txt" \
    "$CONTAINER" \
    bash /data/scripts/run.sh ${SUBJECT_ID} 

