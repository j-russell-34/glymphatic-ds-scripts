#!/bin/bash

#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=concat_alps_wmh
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=4G
#SBATCH --time=00:20:00
#SBATCH --output=logs/concat_alps_wmh_%j.log

#Study specific variables
STUDY="ABCDS_controls"

#load module
module purge
module load apptainer

# Create logs directory if it doesn't exist
mkdir -p logs



# Set up Singularity environment
CONTAINER1="/project2/jasonkru_1564/containers/ccm_analyses/ccmvumc_analyses_v2.1.sif"

# Check if container exists
if [ ! -f "$CONTAINER1" ]; then
    echo "Error: Apptainer container not found at $CONTAINER1"
    exit 1
fi

# Call the processing script with the current array task ID using Apptainer

apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}:/data \
    -B /home1/jasonkru/temp_code/alps-main/wmh_comp:/data/scripts \
    "$CONTAINER1" \
    python /data/scripts/concat_wmh_flair.py

