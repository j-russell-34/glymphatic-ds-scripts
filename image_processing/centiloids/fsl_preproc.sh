#!/bin/bash

# Check if the subject ID argument is provided
if [ $# -lt 1 ]; then
    echo "Error: Missing subject ID argument"
    echo "Usage: $0 <subject_id>"
    exit 1
fi

# Store the subject ID from the command line argument
SUBJECT_ID="$1"
TRACER="$2"

# Check if SUBJECT_ID is set
if [ -z "$SUBJECT_ID" ]; then
    echo "Error: SUBJECT_ID is not set"
    exit 1
fi

# Check if TRACER is set
if [ -z "$TRACER" ]; then
    echo "Error: TRACER is not set"
    echo "Usage: $0 <subject_id> <tracer>"
    exit 1
fi

# Directory containing all subjects
input_dir="/data/subjects/${SUBJECT_ID}/${TRACER}"
output_dir="/data/centiloid/subjects/PROC_${TRACER}/${SUBJECT_ID}"

# Check if input directory exists
if [ ! -d "$input_dir" ]; then
    echo "Error: Input directory does not exist: $input_dir"
    exit 1
fi

# Ensure output directory exists
mkdir -p "$output_dir"
  
# Find the PET image in the current subject's directory
pet_files=($input_dir/*.nii.gz)
pet_image=${pet_files[0]}

# If no .nii.gz file found, try .nii
if [ ! -f "$pet_image" ] || [ "$(basename $pet_image)" == "*.nii.gz" ]; then
    pet_files=($input_dir/*.nii)
    pet_image=${pet_files[0]}
    
    # Check if .nii file exists
    if [ ! -f "$pet_image" ] || [ "$(basename $pet_image)" == "*.nii" ]; then
        echo "Error: No PET image found for subject: $SUBJECT_ID in $input_dir"
        exit 1
    fi
fi

echo "Processing $pet_image"

# Get image dimensions
dim4=$(fslinfo "$pet_image" | grep '^dim4' | awk '{print $2}')

# Check if fslinfo succeeded
if [ $? -ne 0 ]; then
    echo "Error: Failed to get image information using fslinfo for: $pet_image"
    exit 1
fi
  
echo "Processing PET image for subject: $SUBJECT_ID"
  
mean_image="$output_dir/mean_pet.nii.gz"
if [ "$dim4" -gt 1 ]; then
    echo "PET image has $dim4 frames - applying motion correction"
    #MCFLIRT images
    mcflirt_out="$output_dir/pet_mcf.nii.gz"
    mcflirt -in "$pet_image" -out "$mcflirt_out" -stages 4 -mats -plots
    
    if [ $? -ne 0 ]; then
        echo "Error: mcflirt failed for: $pet_image"
        exit 1
    fi
  
    # Calculate the mean of the first 2 volumes
    fslmaths "$mcflirt_out" -roi 0 -1 0 -1 0 -1 0 2 -Tmean "$mean_image"
    
    if [ $? -ne 0 ]; then
        echo "Error: fslmaths failed to calculate mean for: $mcflirt_out"
        exit 1
    fi
else
    echo "PET image only has 1 frame - copying image and proceeding with processing"

    cp "$pet_image" "$mean_image"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy PET image from: $pet_image to: $mean_image"
        exit 1
    fi
fi
  
echo "Mean PET image saved for subject $SUBJECT_ID at: $mean_image"
echo "Processing complete for subject: $SUBJECT_ID"
