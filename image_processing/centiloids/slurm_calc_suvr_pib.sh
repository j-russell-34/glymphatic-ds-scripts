#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=centiloids_pib
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=16G
#SBATCH --time=00:30:00
#SBATCH --output=logs/centpib_%j.log

#Study specific variables
STUDY="ABCDS"

# Check if subject list exists
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/centiloid_pib_subject_list.txt"
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
CONTAINER="/scratch1/jasonkru/containers/centiloids/centiloids_v1.0.0.sif"

# Check if container exists
if [ ! -f "$CONTAINER" ]; then
    echo "Error: Apptainer container not found at $CONTAINER"
    exit 1
fi

apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/centiloids:/data/scripts \
    "$CONTAINER" \
    python /data/scripts/pib_centiloid_calc.py


