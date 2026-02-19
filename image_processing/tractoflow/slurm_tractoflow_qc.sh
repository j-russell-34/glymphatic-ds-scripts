#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=tractoflow_qc
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=16G
#SBATCH --time=48:00:00
#SBATCH --output=logs/tractoflow_qc_%j.log

#Study specific variables
STUDY="ABCDS_controls"
WORK_DIR="/project2/jasonkru_1564/studies/${STUDY}/tractoflow/tractoflow_qc_nf_work"

#create a logs directory
mkdir -p logs

#load module
module purge
module load apptainer


CONTAINER1="/scratch1/jasonkru/containers/scilus/scilus_1.4.2.sif"

if [ ! -f "$CONTAINER1" ]; then
    echo "Error: Apptainer container not found at $CONTAINER1"
    exit 1
fi

module load ver/2506
module load gcc/13.3.0
module load openjdk/17.0.8.1_1

#install nextflow
INPUT_FOLDER="/project2/jasonkru_1564/studies/${STUDY}/tractoflow/tractoflow_output"
OUTPUT_FOLDER="/project2/jasonkru_1564/studies/${STUDY}/tractoflow/tractoflow_qc_output"

mkdir -p $OUTPUT_FOLDER

export NXF_CLUSTER_SEED=$(shuf -i 0-16777216 -n 1)

#run tractoflow_qc
/project2/jasonkru_1564/nextflow_downloads/nextflow run dmriqc_flow/main.nf --input $INPUT_FOLDER -resume \
    -with-singularity $CONTAINER1 -profile tractoflow_qc_all -w $WORK_DIR --output_dir $OUTPUT_FOLDER