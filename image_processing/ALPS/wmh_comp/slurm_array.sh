#!/bin/bash

#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=alps_wmh
#SBATCH --array=1-4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8G
#SBATCH --time=02:00:00
#SBATCH --output=logs/alps_wmh_%A_%a.log

#Study specific variables
STUDY="ABCDS_controls"

# Check if subject list exists
SUBJECT_LIST_FILE="/project2/jasonkru_1564/studies/${STUDY}/subject_list_alps.txt"
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
CONTAINER1="/project2/jasonkru_1564/containers/fs7_4/freesurfer_7.4.1.sif"
CONTAINER2="/project2/jasonkru_1564/containers/ccm_analyses/ccmvumc_analyses_v2.1.sif"

# Check if container exists
if [ ! -f "$CONTAINER1" ]; then
    echo "Error: Apptainer container not found at $CONTAINER1"
    exit 1
fi

if [ ! -f "$CONTAINER2" ]; then
    echo "Error: Apptainer container not found at $CONTAINER2"
    exit 1
fi


# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

mkdir -p /project2/jasonkru_1564/studies/${STUDY}/subjects_dti/OUTPUTS

# Call the processing script with the current array task ID using Apptainer
apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/alps-main/wmh_comp:/data/scripts \
    -B /home1/jasonkru/license/fs_license:/license \
    --env FS_LICENSE="/license/license.txt" \
    "$CONTAINER1" \
    bash /data/scripts/binarize_lesions.sh ${SUBJECT_ID}

apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/alps-main:/data/scripts \
    "$CONTAINER2" \
    python /data/scripts/wmh_comp/compare_wmh_alps.py ${SUBJECT_ID}
