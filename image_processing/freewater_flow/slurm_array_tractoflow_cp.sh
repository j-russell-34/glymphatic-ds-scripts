#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=dti_convert
#SBATCH --array=1-3
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --time=00:05:00
#SBATCH --output=logs/dti_cp_%A_%a.log

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

#make directory for freewater flow
mkdir -p /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}

#cp outputs from tractoflow
cp -ru /project2/jasonkru_1564/studies/${STUDY}/tractoflow/tractoflow_output/${SUBJECT_ID}/Resample_DWI/*.nii.gz /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}
cp -ru /project2/jasonkru_1564/studies/${STUDY}/tractoflow/tractoflow_output/${SUBJECT_ID}/Eddy/*bval* /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}
cp -ru /project2/jasonkru_1564/studies/${STUDY}/tractoflow/tractoflow_output/${SUBJECT_ID}/Eddy/*.bvec /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}
cp -ru /project2/jasonkru_1564/studies/${STUDY}/tractoflow/tractoflow_output/${SUBJECT_ID}/Extract_B0/*mask*.nii.gz /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}

#rename to freewater flow format
mv /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}/*_dwi_resampled.nii.gz /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}/dwi.nii.gz
mv /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}/*bval* /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}/bval
mv /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}/*bvec* /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}/bvec
mv /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}/*mask*.nii.gz /project2/jasonkru_1564/studies/${STUDY}/freewater_flow/${SUBJECT_ID}/brain_mask.nii.gz