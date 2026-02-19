#!/bin/bash

#SBATCH --account=jasonkru_1564
#SBATCH --partition=main
#SBATCH --job-name=dti_convert
#SBATCH --array=1-3
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --time=00:15:00
#SBATCH --output=logs/dti_convert_%A_%a.log

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

#cp scripts to temp code
cp -ru /home1/jasonkru/atri_code/processors/tractoflow /home1/jasonkru/temp_code/

#create a logs directory
mkdir -p logs

#load module
module purge
module load apptainer

#set up singularity environment
CONTAINER1="/scratch1/jasonkru/containers/fs7/fs7.sif"

#check if container exists
if [ ! -f "$CONTAINER1" ]; then
    echo "Error: Apptainer container not found at $CONTAINER1"
    exit 1
fi

#check final directory for dwi and bval and bvec and exit script if present
if [ -f "/project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/dwi.nii.gz" ]; then
    echo "Error: DWI file already exists at /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/dwi.nii.gz"
    exit 1
fi
if [ -f "/project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/bval" ]; then
    echo "Error: BVAL file already exists at /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/bval"
    exit 1
fi
if [ -f "/project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/bvec" ]; then
    echo "Error: BVEC file already exists at /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/bvec"
    exit 1
fi

#tractoflow mkdir
mkdir -p /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}

#check how many .nii.gz files are in the subject directory
nii_files=$(ls /project2/jasonkru_1564/studies/${STUDY}/subjects_dti/${SUBJECT_ID}/dti_files/*.nii.gz | wc -l)
if [ $nii_files -eq 0 ]; then
    echo "Error: No .nii.gz files found in /project2/jasonkru_1564/studies/${STUDY}/subjects_dti/${SUBJECT_ID}/dti_files"
    exit 1
fi

#if there is only one .nii.gz file, run dtialps on it
if [ $nii_files -eq 1 ]; then
    cp -ru /project2/jasonkru_1564/studies/${STUDY}/subjects_dti/${SUBJECT_ID}/dti_files/image*.bval /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}
    cp -ru /project2/jasonkru_1564/studies/${STUDY}/subjects_dti/${SUBJECT_ID}/dti_files/image*.bvec /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}
    cp -ru /project2/jasonkru_1564/studies/${STUDY}/subjects_dti/${SUBJECT_ID}/dti_files/image*.nii.gz /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}

#else if there are more than one .nii.gz files, cp the PA file
elif [ $nii_files -gt 1 ]; then
    cp -ru /project2/jasonkru_1564/studies/${STUDY}/subjects_dti/${SUBJECT_ID}/dti_files/image_PA.bval /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}
    cp -ru /project2/jasonkru_1564/studies/${STUDY}/subjects_dti/${SUBJECT_ID}/dti_files/image_PA.bvec /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}
    cp -ru /project2/jasonkru_1564/studies/${STUDY}/subjects_dti/${SUBJECT_ID}/dti_files/image_PA.nii.gz /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}
#else if there are no .nii.gz files, print an error message
else
    echo "No .nii.gz files found in $subject_dir"
fi


cp -ru /project2/jasonkru_1564/studies/${STUDY}/processed_mri/subjects/${SUBJECT_ID}/mri/orig.mgz /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}
cp -ru /project2/jasonkru_1564/studies/${STUDY}/processed_mri/subjects/${SUBJECT_ID}/mri/aparc+aseg.mgz /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}
cp -ru /project2/jasonkru_1564/studies/${STUDY}/processed_mri/subjects/${SUBJECT_ID}/mri/wmparc.mgz /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}

#rename to tractoflow format
mv /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/image*.nii.gz /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/dwi.nii.gz
mv /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/image*.bval /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/bval
mv /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/image*.bvec /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/bvec
mv /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/orig.mgz /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/t1.mgz


#run tractoflow
apptainer exec \
    -B /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}:/data \
    -B /home1/jasonkru/temp_code/tractoflow:/data/scripts \
    -B /home1/jasonkru/license/fs_license:/license \
    --env FS_LICENSE="/license/license.txt" \
    "$CONTAINER1" \
    bash /data/scripts/convert_mri.sh

#rm old mgz files
rm /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/t1.mgz
rm /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/aparc+aseg.mgz
rm /project2/jasonkru_1564/studies/${STUDY}/tractoflow/${SUBJECT_ID}/wmparc.mgz



