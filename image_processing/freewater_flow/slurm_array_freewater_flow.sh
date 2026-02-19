#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=oneweek
#SBATCH --job-name=freewater_flow
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=36:00:00
#SBATCH --output=logs/freewater_flow_%j.log

# Nextflow will submit tasks to SLURM

export NXF_CLUSTER_SEED=$(shuf -i 0-16777216 -n 1)

#Study specific variables
STUDY="ABCDS_controls"

#create a logs directory
mkdir -p logs

#load module
module purge
module load apptainer

CONTAINER1="/scratch1/jasonkru/containers/freewater_flow/scilus_latest.sif"

if [ ! -f "$CONTAINER1" ]; then
    echo "Error: Apptainer container not found at $CONTAINER1"
    exit 1
fi

module load ver/2506
module load gcc/13.3.0
module load openjdk/17.0.8.1_1

#install nextflow
INPUT_FOLDER="/project2/jasonkru_1564/studies/${STUDY}/freewater_flow/"
OUTPUT_FOLDER="/project2/jasonkru_1564/studies/${STUDY}/freewater_flow/freewater_flow_output"
WORK_DIR="/project2/jasonkru_1564/studies/${STUDY}/freewater_flow/nf_work"

mkdir -p "$OUTPUT_FOLDER" "$WORK_DIR"

# Ensure scilpy CLI scripts resolve and use the venv python inside container
# Put the venv bin FIRST so script shebangs like `#!/usr/bin/env python` pick it up
export APPTAINERENV_PATH="/opt/venvs/scilpy/bin:/scilpy/src/scilpy/cli:/usr/local/bin:/usr/bin:/bin"
export SINGULARITYENV_PATH="$APPTAINERENV_PATH"

#run freewater_flow as a driver (no srun); tasks are scheduled by Nextflow via SLURM
/project2/jasonkru_1564/nextflow_downloads/nextflow run main.nf \
    --input "$INPUT_FOLDER" \
    --output_dir "$OUTPUT_FOLDER" \
    -w "$WORK_DIR" \
    -with-singularity "$CONTAINER1" \
    -resume

