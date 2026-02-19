#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=centiloids
#SBATCH --array=1-4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8G
#SBATCH --time=01:00:00
#SBATCH --output=logs/cent_%A_%a.log

# Study specific variables
STUDY="ABCDS"
TRACER="pib"

# Check if subject list exists
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/centiloid_${TRACER}_subject_list.txt"
if [ ! -f "$SUBJECT_LIST_FILE" ]; then
    echo "Error: Subject list not found at $SUBJECT_LIST_FILE"
    echo "Please run generate_subject_list.sh"
    exit 1
fi

# Load module
module purge
module load apptainer

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up Singularity environment
CONTAINER="/scratch1/jasonkru/containers/centiloids/centiloids_v1.0.0.sif"

# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo "Error: Apptainer container not found at $CONTAINER"
    exit 1
fi

# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

# Check if SUBJECT_ID is set
if [ -z "$SUBJECT_ID" ]; then
    echo "Error: SUBJECT_ID is not set. Check that line ${SLURM_ARRAY_TASK_ID} exists in $SUBJECT_LIST_FILE"
    exit 1
fi

echo "Processing subject: $SUBJECT_ID"



# Create necessary directories
mkdir -p /project2/jasonkru_1564/studies/${STUDY}/centiloid/subjects/PROC_${TRACER}


# Run the container
apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/centiloids:/data/scripts \
    "$CONTAINER" \
    bash /data/scripts/run_cent.sh ${SUBJECT_ID} ${TRACER}
