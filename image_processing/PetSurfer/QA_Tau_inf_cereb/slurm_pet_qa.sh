#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --array=1-10
#SBATCH --job-name=tau_qa
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4G
#SBATCH --time=0:30:00
#SBATCH --output=logs/qa_%A_%a.log

#Study specific variables
STUDY="ABCDS"

# Create logs directory if it doesn't exist
mkdir -p logs

# Load required modules
module purge
module load apptainer

# Set up environment variables and paths
CONTAINER="/project2/jasonkru_1564/containers/fs_qa/fs7_post_v1.sif"
# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo "Error: Apptainer container not found at $CONTAINER"
    exit 1
fi

SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/tau_subject_list.txt"

# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

tmpxkb="$(mktemp -d)"

# Create a temporary directory for XDG runtime
export XDG_RUNTIME_DIR="/tmp/runtime_${SLURM_JOB_ID}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Run the QA script using Apptainer
apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/QA_Tau_inf_cereb:/data/scripts \
    -B /home1/jasonkru/license/fs_license:/license \
    -B "$tmpxkb":/var/lib/xkb \
    -B /tmp/runtime_${SLURM_JOB_ID}:/tmp/runtime_${SLURM_JOB_ID} \
    --env SUBJECTS_DIR="/data/subjects" \
    --env FS_LICENSE="/license/license.txt" \
    --env XDG_RUNTIME_DIR="/tmp/runtime_${SLURM_JOB_ID}" \
    "$CONTAINER" \
    bash /data/scripts/fs_pet.sh ${SLURM_ARRAY_TASK_ID} 


