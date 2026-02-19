#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=inf_cereb
#SBATCH --array=1-4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4G
#SBATCH --time=04:00:00
#SBATCH --output=logs/tau_%A_%a.log

#Study specific variables
STUDY="ABCDS"

export STUDY="$STUDY"

# Check if subject list exists
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/cblm_subject_list.txt"
if [ ! -f "$SUBJECT_LIST_FILE" ]; then
    echo "Error: Subject list not found. Please run cblm_subject_list.sh first"
    exit 1
fi


SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/cblm_subject_list.txt"

# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")
export SUBJECT_ID="$SUBJECT_ID"

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

# Generate SUB_ID_NO_E by removing the underscore and everything after it
SUB_ID_NO_E="${SUBJECT_ID%%_*}"

export SUB_ID_NO_E="$SUB_ID_NO_E"
echo "SUB_ID_NO_E: $SUB_ID_NO_E"


module purge
module load apptainer


# Create logs directory if it doesn't exist
mkdir -p logs

# Set up Singularity environment
CONTAINER1="/scratch1/jasonkru/containers/centiloids/centiloids_v1.0.0.sif"
CONTAINER2="/scratch1/jasonkru/containers/fs7/fs7.sif"


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

mkdir -p /project2/jasonkru_1564/studies/${STUDY}/tau_inf_cereb_grey/subjects/${SUBJECT_ID}

#Call the processing script with the current array task ID using Apptainer
apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/tau_inf_cereb_ref:/data/scripts \
    -B /home1/jasonkru/license/fs_license:/license \
    --env SUBJECTS_DIR="/data/subjects" \
    --env FS_LICENSE="/license/license.txt" \
    "$CONTAINER2" \
    bash /data/scripts/cerebellar_grey_roi.sh ${SLURM_ARRAY_TASK_ID}

apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/tau_inf_cereb_ref:/data/scripts \
    --env SUBJECTS_DIR="/data/subjects" \
    "$CONTAINER1" \
    python /data/scripts/reorient.py ${SLURM_ARRAY_TASK_ID}


#load matlab module
module load matlab
matlab -nodesktop -nosplash -r "addpath('/scratch1/jasonkru/software/matlab/spm12/'); addpath('/home1/jasonkru/temp_code/tau_inf_cereb_ref/spm_auto_reorient/');  addpath(genpath('/scratch1/jasonkru/software/matlab/toolbox/')); subject_id = getenv('SUBJECT_ID'); study = getenv('STUDY'); inferior_cerebellum(subject_id, study); exit;"


module purge
module load apptainer

# Call the processing script with the current array task ID using Apptainer
apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/tau_inf_cereb_ref:/data/scripts \
    --env SUBJECTS_DIR="/data/subjects" \
    "$CONTAINER1" \
    python /data/scripts/inf_cerebellar_mask.py ${SLURM_ARRAY_TASK_ID} 

apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/tau_inf_cereb_ref:/data/scripts \
    -B /home1/jasonkru/license/fs_license:/license \
    --env SUBJECTS_DIR="/data/subjects" \
    --env FS_LICENSE="/license/license.txt" \
    "$CONTAINER2" \
    bash /data/scripts/xform2long.sh ${SLURM_ARRAY_TASK_ID} ${SUB_ID_NO_E}

