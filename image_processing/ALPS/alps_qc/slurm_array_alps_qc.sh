#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=dti_alps
#SBATCH --array=1-4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=8G
#SBATCH --time=00:15:00
#SBATCH --output=logs/dti_alps_%A_%a.log

#Study specific variables
STUDY="ABCDS"

# Check if subject list exists
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/subject_list_alps_qc.txt"
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
CONTAINER="/project2/jasonkru_1564/containers/centiloids/centiloids_v1.0.0.sif"

# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo "Error: Apptainer container not found at $CONTAINER"
    exit 1
fi

SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/subject_list_alps_qc.txt"

# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

mkdir -p /project2/jasonkru_1564/studies/${STUDY}/subjects_dti/OUTPUTS/ALPS_QC

# Call the processing script with the current array task ID using Apptainer
apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}/subjects_dti:/data \
    -B /home1/jasonkru/temp_code/alps-main/alps_qc:/data/scripts \
    "$CONTAINER" \
    python /data/scripts/generate_qc.py ${SUBJECT_ID}


