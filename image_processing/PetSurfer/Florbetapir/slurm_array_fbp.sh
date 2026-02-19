#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=fbp_petsurfer
#SBATCH --array=1-4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4G
#SBATCH --time=24:00:00
#SBATCH --output=logs/fbp_%A_%a.log

#Study specific variables
STUDY="ABCDS"
PSF_CSV="/data/csvs/ABCDS_filters.csv"
RADIOTRACER="fbp"

# Check if subject list exists
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/fbp_subject_list.txt"
if [ ! -f "$SUBJECT_LIST_FILE" ]; then
    echo "Error: Subject list not found. Please run fbp_subject_list.sh first"
    exit 1
fi

#load module
module purge
module load apptainer

# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p logs

# Set up Singularity environment
CONTAINER1="/project2/jasonkru_1564/containers/fsl/fsl.sif"
CONTAINER2="/project2/jasonkru_1564/containers/fs7/fs7.sif"

# Check if container exists
if [ ! -f "$CONTAINER1" ]; then
    echo "Error: Apptainer container not found at $CONTAINER1"
    exit 1
fi

# Check if container exists
if [ ! -f "$CONTAINER2" ]; then
    echo "Error: Apptainer container not found at $CONTAINER2"
    exit 1
fi

# Call the processing script with the current array task ID using Apptainer
apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/Florbetapir:/data/scripts \
    --env SUBJECTS_DIR="/data/subjects" \
    "$CONTAINER1" \
    bash /data/scripts/fsl_preproc.sh ${SUBJECT_ID} ${RADIOTRACER}


# Call the processing script with the current array task ID using Apptainer
apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/Florbetapir:/data/scripts \
    -B /home1/jasonkru/license/fs_license:/license \
    --env SUBJECTS_DIR="/data/subjects" \
    --env FS_LICENSE="/license/license.txt" \
    "$CONTAINER2" \
    bash /data/scripts/run_fbp_EWM.sh ${SUBJECT_ID} ${RADIOTRACER} ${PSF_CSV}

