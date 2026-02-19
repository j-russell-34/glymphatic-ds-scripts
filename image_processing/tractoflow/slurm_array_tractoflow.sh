#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=oneweek
#SBATCH --job-name=tractoflow
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=72:00:00
#SBATCH --output=logs/tractoflow_%j.log

export NXF_CLUSTER_SEED=$(shuf -i 0-16777216 -n 1)

#Study specific variables
STUDY="ABCDS_controls"

#create a logs directory
mkdir -p logs

#load module
module purge
module load apptainer


CONTAINER1="/scratch1/jasonkru/containers/tractoflow/scilus_1.6.0.sif"

if [ ! -f "$CONTAINER1" ]; then
    echo "Error: Apptainer container not found at $CONTAINER1"
    exit 1
fi

module load ver/2506
module load gcc/13.3.0
module load openjdk/17.0.8.1_1

#install nextflow
INPUT_FOLDER="/project2/jasonkru_1564/studies/${STUDY}/tractoflow/"
OUTPUT_FOLDER="/project2/jasonkru_1564/studies/${STUDY}/tractoflow/tractoflow_output"

mkdir -p $OUTPUT_FOLDER

#run tractoflow
srun /project2/jasonkru_1564/nextflow_downloads/nextflow -c singularity.conf run scilus/tractoflow -r 2.4.3 --input $INPUT_FOLDER -with-singularity $CONTAINER1 --max_dti_shell_value 2200 --output_dir $OUTPUT_FOLDER -with-mpi -resume


