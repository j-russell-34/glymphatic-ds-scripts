#!/bin/bash

# Check if SLURM_ARRAY_TASK_ID is set
if [ -z "$SLURM_ARRAY_TASK_ID" ]; then
    echo "Error: SLURM_ARRAY_TASK_ID is not set"
    exit 1
fi

# Check if RADIOTRACER is provided
if [ -z "$2" ]; then
    echo "Error: RADIOTRACER not provided"
    exit 1
fi

# Check if PSF_CSV is provided
if [ -z "$3" ]; then
    echo "Error: PSF_CSV not provided"
    exit 1
fi

RADIOTRACER="$2"
PSF_CSV="$3"

export RADIOTRACER="$RADIOTRACER"
export PSF_CSV="$PSF_CSV"

echo "Running run_tau.sh"
bash run_tau.sh ${SLURM_ARRAY_TASK_ID} ${RADIOTRACER} ${PSF_CSV}

echo "Running suvrs.sh"
bash suvrs.sh ${SLURM_ARRAY_TASK_ID} ${RADIOTRACER}

echo "Done"