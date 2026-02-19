#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=choroid_plexus_fw
#SBATCH --array=1-3
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=8G
#SBATCH --time=00:30:00
#SBATCH --output=logs/choroid_plexus_fw_%A_%a.log

# Ensure logs directory exists
mkdir -p logs

#Study specific variables
STUDY="ABCDS_controls"

# Check if subject list exists
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/subject_list_tractoflow.txt"
if [ ! -f "$SUBJECT_LIST_FILE" ]; then
    echo "Error: Subject list not found. Please run generate_subject_list.sh first"
    exit 1
fi

#get the subject id from the list file using the slurm array task id
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

# Set up Singularity environment
CONTAINER="/scratch1/jasonkru/containers/fs7/fs7.sif"

# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo "Error: Apptainer container not found at $CONTAINER"
    exit 1
fi

module purge
module load apptainer

apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /project2/jasonkru_1564/studies/${STUDY}:/project2/jasonkru_1564/studies/${STUDY} \
    -B /home1/jasonkru/temp_code/freewater_flow:/data/scripts \
    -B /home1/jasonkru/license/fs_license:/license \
    --env SUBJECTS_DIR="/data/subjects" \
    --env FS_LICENSE="/license/license.txt" \
    "$CONTAINER" \
    bash /data/scripts/choroid_plexus_fw.sh ${SUBJECT_ID}