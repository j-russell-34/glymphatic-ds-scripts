#!/bin/bash

# Set up environment variables for container paths
SUBJECTS_MRI_DIR="/data/processed_mri/subjects"
SUBJECTS_PET_DIR="/data/pib/subjects"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Get the subject ID from the command line argument
SUBJECT_ID=$1

# Echo the job information
echo "Subject ID: $SUBJECT_ID"
echo "Subject Directory: $SUBJECTS_DIR/$SUBJECT_ID"
echo "Running in Apptainer container"

#set up output directory
OUTPUT_DIR="/data/OUTPUT"
QA_DIR="$OUTPUT_DIR/Pib_QA_BG_Reports"
mkdir -p "$QA_DIR"

# Create temporary configuration directory for freeview
TEMP_CONFIG_DIR="/tmp/freeview_config_${USER}"
mkdir -p "$TEMP_CONFIG_DIR"
chmod 700 "$TEMP_CONFIG_DIR"
export XDG_CONFIG_HOME="$TEMP_CONFIG_DIR"

# Ensure freeview and fsxvfb are available
if ! command -v freeview &> /dev/null; then
    echo "ERROR: freeview not found in PATH"
    exit 1
fi

modality="pib"

# Function to generate QA images for a subject's PET data
generate_pet_qa_images() {
    local subject=$1
    local pet_dir=$modality
    local output_dir="$QA_DIR/${subject}_${pet_dir}"
    mkdir -p "$output_dir"
    
    # Extract the base subject ID for longitudinal processing
    local sub_id_no_e="${subject%%_*}"
    local subject_long="${subject}.long.${sub_id_no_e}_base"
    
    echo "Processing subject: $subject, PET modality: $pet_dir"
    echo "Longitudinal subject: $subject_long"
    
    # Check if required files exist
    if [ ! -f "$SUBJECTS_PET_DIR/$subject/gtmpvc.output/rbv.nii.gz" ]; then
        echo "Error: rbv.nii.gz not found for $subject/$pet_dir"
        return 1
    fi
    
    if [ ! -f "$SUBJECTS_PET_DIR/$subject/gtmpvc.output/input.rescaled.nii.gz" ]; then
        echo "Error: input.rescaled.nii.gz not found for $subject/$pet_dir"
        return 1
    fi
    
    if [ ! -f "$SUBJECTS_MRI_DIR/$subject_long/mri/orig.mgz" ]; then
        echo "Error: orig.mgz not found for $subject_long"
        return 1
    fi

    if [ ! -f "$SUBJECTS_PET_DIR/$subject/basal_ganglia.nii.gz" ]; then
        echo "Error: basal_ganglia.nii.gz not found for $subject"
        return 1
    fi

    # Row 1: PET rbv.nii.gz overlaid on MRI orig.mgz
    # Sagittal view
    echo "Running freeview command for sagittal view..."
    xvfb-run -a --server-args "-screen 0 1920x1080x24" freeview -v \
        "$SUBJECTS_MRI_DIR/$subject/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/gtmpvc.output/rbv.nii.gz":colormap=heat:opacity=0.5 \
        --layout 1 --viewport sagittal \
        --screenshot "$output_dir/${subject}_${pet_dir}_rbv_sagittal.png" \
        --quit

    if [ ! -s "$output_dir/${subject}_${pet_dir}_rbv_sagittal.png" ]; then
        echo "Error: Failed to generate sagittal PNG for $subject ($pet_dir)"
        return 1
    fi
    echo "OK: $output_dir/${subject}_${pet_dir}_rbv_sagittal.png"

    
    # Coronal view
    echo "Running freeview command for coronal view..."
    xvfb-run -a --server-args "-screen 0 1920x1080x24" freeview -v \
        "$SUBJECTS_MRI_DIR/$subject/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/gtmpvc.output/rbv.nii.gz":colormap=heat:opacity=0.5 \
        --layout 1 --viewport coronal \
        --screenshot "$output_dir/${subject}_${pet_dir}_rbv_coronal.png" \
        --quit

    if [ ! -s "$output_dir/${subject}_${pet_dir}_rbv_coronal.png" ]; then
        echo "Error: Failed to generate coronal PNG for $subject ($pet_dir)"
        return 1
    fi
    echo "OK: $output_dir/${subject}_${pet_dir}_rbv_coronal.png"
    
    # Axial view
    echo "Running freeview command for axial view..."
    xvfb-run -a --server-args "-screen 0 1920x1080x24" freeview -v \
        "$SUBJECTS_MRI_DIR/$subject/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/gtmpvc.output/rbv.nii.gz":colormap=heat:opacity=0.5 \
        --layout 1 --viewport axial \
        --screenshot "$output_dir/${subject}_${pet_dir}_rbv_axial.png" \
        --quit

    if [ ! -s "$output_dir/${subject}_${pet_dir}_rbv_axial.png" ]; then
        echo "Error: Failed to generate axial PNG for $subject ($pet_dir)"
        return 1
    fi
    echo "OK: $output_dir/${subject}_${pet_dir}_rbv_axial.png"
    
    # Row 2: PET input.rescaled.nii.gz overlaid on MRI orig.mgz
    # Sagittal view
    echo "Running freeview command for input sagittal view..."
    xvfb-run -a --server-args "-screen 0 1920x1080x24" freeview -v \
        "$SUBJECTS_MRI_DIR/$subject_long/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/gtmpvc.output/rbv.long.nii.gz":colormap=heat:opacity=0.5 \
        "$SUBJECTS_PET_DIR/$subject/basal_ganglia.nii.gz":colormap=lut:lut=$SCRIPT_DIR/basal_ganglia.ctab:opacity=0.7 \
        --layout 1 --viewport sagittal \
        --screenshot "$output_dir/${subject}_${pet_dir}_input_sagittal.png" \
        --quit

    if [ ! -s "$output_dir/${subject}_${pet_dir}_input_sagittal.png" ]; then
        echo "Error: Failed to generate input sagittal PNG for $subject ($pet_dir)"
        return 1
    fi
    echo "OK: $output_dir/${subject}_${pet_dir}_input_sagittal.png"
    
    
    # Coronal view
    echo "Running freeview command for input coronal view..."
    xvfb-run -a --server-args "-screen 0 1920x1080x24" freeview -v \
        "$SUBJECTS_MRI_DIR/$subject_long/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/gtmpvc.output/rbv.long.nii.gz":colormap=heat:opacity=0.5 \
        "$SUBJECTS_PET_DIR/$subject/basal_ganglia.nii.gz":colormap=lut:lut=$SCRIPT_DIR/basal_ganglia.ctab:opacity=0.7 \
        --layout 1 --viewport coronal \
        --screenshot "$output_dir/${subject}_${pet_dir}_input_coronal.png" \
        --quit

    if [ ! -s "$output_dir/${subject}_${pet_dir}_input_coronal.png" ]; then
        echo "Error: Failed to generate input coronal PNG for $subject ($pet_dir)"
        return 1
    fi
    echo "OK: $output_dir/${subject}_${pet_dir}_input_coronal.png"
    
    # Axial view
    echo "Running freeview command for input axial view..."
    xvfb-run -a --server-args "-screen 0 1920x1080x24" freeview -v \
        "$SUBJECTS_MRI_DIR/$subject_long/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/gtmpvc.output/rbv.long.nii.gz":colormap=heat:opacity=0.5 \
        "$SUBJECTS_PET_DIR/$subject/basal_ganglia.nii.gz":colormap=lut:lut=$SCRIPT_DIR/basal_ganglia.ctab:opacity=0.7 \
        --layout 1 --viewport axial \
        --screenshot "$output_dir/${subject}_${pet_dir}_input_axial.png" \
        --quit

    if [ ! -s "$output_dir/${subject}_${pet_dir}_input_axial.png" ]; then
        echo "Error: Failed to generate input axial PNG for $subject ($pet_dir)"
        return 1
    fi
    echo "OK: $output_dir/${subject}_${pet_dir}_input_axial.png"

    echo "QA images generated for $subject ($pet_dir)"

    # Verify all expected PNGs exist before montage
    for img in \
        "$output_dir/${subject}_${pet_dir}_rbv_sagittal.png" \
        "$output_dir/${subject}_${pet_dir}_rbv_coronal.png" \
        "$output_dir/${subject}_${pet_dir}_rbv_axial.png" \
        "$output_dir/${subject}_${pet_dir}_input_sagittal.png" \
        "$output_dir/${subject}_${pet_dir}_input_coronal.png" \
        "$output_dir/${subject}_${pet_dir}_input_axial.png"; do
        if [ ! -s "$img" ]; then
            echo "ERROR: missing expected image $img"
            return 1
        fi
    done

    # Create a PDF page using ImageMagick
    montage \
        "$output_dir/${subject}_${pet_dir}_rbv_sagittal.png" "$output_dir/${subject}_${pet_dir}_rbv_coronal.png" "$output_dir/${subject}_${pet_dir}_rbv_axial.png" \
        "$output_dir/${subject}_${pet_dir}_input_sagittal.png" "$output_dir/${subject}_${pet_dir}_input_coronal.png" "$output_dir/${subject}_${pet_dir}_input_axial.png" \
        -tile 3x2 -geometry +5+5 \
        "$output_dir/${subject}_${pet_dir}_brain_grid.png"

    # Convert the montage to a centered PDF that fills the page
    convert -page 1300x800 "$output_dir/${subject}_${pet_dir}_brain_grid.png" "$output_dir/${subject}_${pet_dir}_PETqa_BG.pdf"

    # Add after PDF creation
    if [ ! -s "$output_dir/${subject}_${pet_dir}_PETqa_BG.pdf" ]; then
        echo "Error: Failed to create PDF for $subject ($pet_dir)"
        return 1
    fi

    echo "QA PDFs generated for $subject ($pet_dir)"
    mv "$output_dir/${subject}_${pet_dir}_PETqa_BG.pdf" "$QA_DIR/${subject}_${pet_dir}_PETqa_BG.pdf"
    rm -rf "$output_dir"
}

# Process each subject for each PET modality
process_subjects() {
    local pet_modality=$modality
    
    subject_dir="$SUBJECTS_PET_DIR/$SUBJECT_ID"
    if [ -d "$subject_dir" ]; then
        subject=$(basename "$subject_dir")
        
        # Check if this subject has the specified PET modality
        if [ -d "$subject_dir" ]; then
            echo "Found $pet_modality data for subject: $subject"
            generate_pet_qa_images "$subject" "$pet_modality"
        fi
    fi
}

# Process each PET modality
echo "Processing $modality PET data..."
process_subjects "$modality"

# Clean up temporary configuration directory
rm -rf "$TEMP_CONFIG_DIR"

echo "PET QA images generation complete."