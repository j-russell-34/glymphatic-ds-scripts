#!/bin/bash

set -euo pipefail

modality="ftp"

# Resolve script directory for LUTs and other assets
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Check if SLURM_ARRAY_TASK_ID is set
if [ -z "$SLURM_ARRAY_TASK_ID" ]; then
    echo "Error: SLURM_ARRAY_TASK_ID is not set"
    exit 1
fi

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/processed_mri/subjects"
SUBJECT_LIST_FILE="/data/tau_subject_list.txt"
SUBJECTS_PET_DIR="/data/tau_inf_cereb_grey/subjects"
export SUBJECTS_DIR="$SUBJECTS_BASE_DIR"
export SUBJECTS_PET_DIR="$SUBJECTS_PET_DIR"

# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

# Echo the job information
echo "Task ID: $SLURM_ARRAY_TASK_ID"
echo "Subject ID: $SUBJECT_ID"
echo "Subject Directory: $SUBJECTS_DIR/$SUBJECT_ID"
echo "Running in Apptainer container"

#set up output directory
OUTPUT_DIR="/data/OUTPUT"
QA_DIR="$OUTPUT_DIR/QA_Reports/FTP_PET"
mkdir -p "$QA_DIR"

# Create temporary configuration directory for freeview
TEMP_CONFIG_DIR="/tmp/freeview_config_${USER}"
mkdir -p "$TEMP_CONFIG_DIR"
chmod 700 "$TEMP_CONFIG_DIR"
export XDG_CONFIG_HOME="$TEMP_CONFIG_DIR"

# Ensure freeview and xvfb-run are available
if ! command -v freeview &> /dev/null; then
    echo "ERROR: freeview not found in PATH"
    exit 1
fi

if ! command -v xvfb-run &> /dev/null; then
    echo "ERROR: xvfb-run not found in PATH"
    exit 1
fi

# Wrapper to run freeview under Xvfb and capture stdout/stderr for debugging
run_freeview() {
    local label=$1
    local log_path=$2
    shift 2
    if ! xvfb-run -a --server-args "-screen 0 1920x1080x24" "$@" >"$log_path" 2>&1; then
        echo "Error: freeview failed for ${label}. See log: ${log_path}"
        return 1
    fi
}



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
    if [ ! -f "$SUBJECTS_PET_DIR/$subject/$pet_dir/gtmpvc_inf_cereb.output/rbv.long.nii.gz" ]; then
        echo "Error: rbv.long.nii.gz not found for $subject/$pet_dir"
        return 1
    fi
    if [ ! -f "$SUBJECTS_PET_DIR/$subject/$pet_dir/gtmpvc_inf_cereb.output/rbv.nii.gz" ]; then
        echo "Error: rbv.nii.gz not found for $subject/$pet_dir"
        return 1
    fi
    if [ ! -f "$SUBJECTS_PET_DIR/$subject/$pet_dir/gtmpvc_inf_cereb.output/input.rescaled.nii.gz" ]; then
        echo "Error: input.rescaled.nii.gz not found for $subject/$pet_dir"
        return 1
    fi
    if [ ! -f "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak12_composite_icref.nii.gz" ]; then
        echo "Error: braak12_composite_icref.nii.gz not found for $subject/$pet_dir"
        return 1
    fi
    if [ ! -f "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak34_composite_icref.nii.gz" ]; then
        echo "Error: braak34_composite_icref.nii.gz not found for $subject/$pet_dir"
        return 1
    fi
    if [ ! -f "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak56_composite_icref.nii.gz" ]; then
        echo "Error: braak56_composite_icref.nii.gz not found for $subject/$pet_dir"
        return 1
    fi
    if [ ! -f "$SUBJECTS_BASE_DIR/$subject/mri/gtmseg+infcereb_long.mgz" ]; then
        echo "Error: gtmseg+infcereb_long.mgz not found for $subject"
        return 1
    fi
    if [ ! -f "$SUBJECTS_BASE_DIR/$subject/mri/gtmseg+infcereb.mgz" ]; then
        echo "Error: gtmseg+infcereb.mgz not found for $subject"
        return 1
    fi
    if [ ! -f "$SUBJECTS_DIR/$subject_long/mri/orig.mgz" ]; then
        echo "Error: orig.mgz not found for $subject_long"
        return 1
    fi

    # Row 1: PET rbv.nii.gz overlaid on MRI orig.mgz
    # Sagittal view
    echo "Running freeview command for sagittal view (log: $output_dir/${subject}_${pet_dir}_rbv_sagittal.log)..."
    run_freeview "rbv sagittal" "$output_dir/${subject}_${pet_dir}_rbv_sagittal.log" \
        freeview -v \
        "$SUBJECTS_DIR/$subject_long/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/gtmpvc_inf_cereb.output/rbv.long.nii.gz":colormap=heat:opacity=0.5 \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak12_composite_icref.nii.gz":colormap=lut:lut=$SCRIPT_DIR/braak12.ctab:opacity=0.2 \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak34_composite_icref.nii.gz":colormap=lut:lut=$SCRIPT_DIR/braak34.ctab:opacity=0.2 \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak56_composite_icref.nii.gz":colormap=lut:lut=$SCRIPT_DIR/braak56.ctab:opacity=0.2 \
        "$SUBJECTS_BASE_DIR/$subject/mri/gtmseg+infcereb_long.mgz":colormap=lut:lut=$SCRIPT_DIR/infcereb.ctab:opacity=0.4 \
        --layout 1 --viewport sagittal \
        --screenshot "$output_dir/${subject}_${pet_dir}_rbv_sagittal.png" \
        --quit
    if [ $? -ne 0 ]; then
        echo "freeview sagittal failed; log follows:" && cat "$output_dir/${subject}_${pet_dir}_rbv_sagittal.log" 1>&2
        return 1
    fi

    # Verify the PNG was created
    if [ ! -f "$output_dir/${subject}_${pet_dir}_rbv_sagittal.png" ]; then
        echo "Error: Failed to generate sagittal PNG for $subject ($pet_dir)"
        return 1
    fi
    
    # Coronal view
    echo "Running freeview command for coronal view (log: $output_dir/${subject}_${pet_dir}_rbv_coronal.log)..."
    run_freeview "rbv coronal" "$output_dir/${subject}_${pet_dir}_rbv_coronal.log" \
        freeview -v \
        "$SUBJECTS_DIR/$subject_long/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/gtmpvc_inf_cereb.output/rbv.long.nii.gz":colormap=heat:opacity=0.5 \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak12_composite_icref.nii.gz":colormap=lut:lut=$SCRIPT_DIR/braak12.ctab:opacity=0.2 \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak34_composite_icref.nii.gz":colormap=lut:lut=$SCRIPT_DIR/braak34.ctab:opacity=0.2 \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak56_composite_icref.nii.gz":colormap=lut:lut=$SCRIPT_DIR/braak56.ctab:opacity=0.2 \
        "$SUBJECTS_BASE_DIR/$subject/mri/gtmseg+infcereb_long.mgz":colormap=lut:lut=$SCRIPT_DIR/infcereb.ctab:opacity=0.4 \
        --layout 1 --viewport coronal \
        --screenshot "$output_dir/${subject}_${pet_dir}_rbv_coronal.png" \
        --quit
    if [ $? -ne 0 ]; then
        echo "freeview coronal failed; log follows:" && cat "$output_dir/${subject}_${pet_dir}_rbv_coronal.log" 1>&2
        return 1
    fi

    # Verify the PNG was created
    if [ ! -f "$output_dir/${subject}_${pet_dir}_rbv_coronal.png" ]; then
        echo "Error: Failed to generate coronal PNG for $subject ($pet_dir)"
        return 1
    fi
    
    # Axial view
    echo "Running freeview command for axial view (log: $output_dir/${subject}_${pet_dir}_rbv_axial.log)..."
    run_freeview "rbv axial" "$output_dir/${subject}_${pet_dir}_rbv_axial.log" \
        freeview -v \
        "$SUBJECTS_DIR/$subject_long/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/gtmpvc_inf_cereb.output/rbv.long.nii.gz":colormap=heat:opacity=0.5 \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak12_composite_icref.nii.gz":colormap=lut:lut=$SCRIPT_DIR/braak12.ctab:opacity=0.2 \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak34_composite_icref.nii.gz":colormap=lut:lut=$SCRIPT_DIR/braak34.ctab:opacity=0.2 \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/braak56_composite_icref.nii.gz":colormap=lut:lut=$SCRIPT_DIR/braak56.ctab:opacity=0.2 \
        "$SUBJECTS_BASE_DIR/$subject/mri/gtmseg+infcereb_long.mgz":colormap=lut:lut=$SCRIPT_DIR/infcereb.ctab:opacity=0.4 \
        --layout 1 --viewport axial \
        --screenshot "$output_dir/${subject}_${pet_dir}_rbv_axial.png" \
        --quit
    if [ $? -ne 0 ]; then
        echo "freeview axial failed; log follows:" && cat "$output_dir/${subject}_${pet_dir}_rbv_axial.log" 1>&2
        return 1
    fi

    # Verify the PNG was created
    if [ ! -f "$output_dir/${subject}_${pet_dir}_rbv_axial.png" ]; then
        echo "Error: Failed to generate axial PNG for $subject ($pet_dir)"
        return 1
    fi
    
    # Row 2: PET input.rescaled.nii.gz overlaid on MRI orig.mgz
    # Sagittal view
    echo "Running freeview command for input sagittal view (log: $output_dir/${subject}_${pet_dir}_input_sagittal.log)..."
    run_freeview "input sagittal" "$output_dir/${subject}_${pet_dir}_input_sagittal.log" \
        freeview -v \
        "$SUBJECTS_DIR/$subject/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/gtmpvc_inf_cereb.output/rbv.nii.gz":colormap=heat:opacity=0.5 \
        "$SUBJECTS_BASE_DIR/$subject/mri/gtmseg+infcereb.mgz":colormap=lut:lut=$SCRIPT_DIR/infcereb.ctab:opacity=0.4 \
        --layout 1 --viewport sagittal \
        --screenshot "$output_dir/${subject}_${pet_dir}_input_sagittal.png" \
        --quit
    if [ $? -ne 0 ]; then
        echo "freeview input sagittal failed; log follows:" && cat "$output_dir/${subject}_${pet_dir}_input_sagittal.log" 1>&2
        return 1
    fi

    # Verify the PNG was created
    if [ ! -f "$output_dir/${subject}_${pet_dir}_input_sagittal.png" ]; then
        echo "Error: Failed to generate input sagittal PNG for $subject ($pet_dir)"
        return 1
    fi
    
    # Coronal view
    echo "Running freeview command for input coronal view (log: $output_dir/${subject}_${pet_dir}_input_coronal.log)..."
    run_freeview "input coronal" "$output_dir/${subject}_${pet_dir}_input_coronal.log" \
        freeview -v \
        "$SUBJECTS_DIR/$subject/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/gtmpvc_inf_cereb.output/rbv.nii.gz":colormap=heat:opacity=0.5 \
        "$SUBJECTS_BASE_DIR/$subject/mri/gtmseg+infcereb.mgz":colormap=lut:lut=$SCRIPT_DIR/infcereb.ctab:opacity=0.4 \
        --layout 1 --viewport coronal \
        --screenshot "$output_dir/${subject}_${pet_dir}_input_coronal.png" \
        --quit
    if [ $? -ne 0 ]; then
        echo "freeview input coronal failed; log follows:" && cat "$output_dir/${subject}_${pet_dir}_input_coronal.log" 1>&2
        return 1
    fi

    # Verify the PNG was created
    if [ ! -f "$output_dir/${subject}_${pet_dir}_input_coronal.png" ]; then
        echo "Error: Failed to generate input coronal PNG for $subject ($pet_dir)"
        return 1
    fi
    
    # Axial view
    echo "Running freeview command for input axial view (log: $output_dir/${subject}_${pet_dir}_input_axial.log)..."
    run_freeview "input axial" "$output_dir/${subject}_${pet_dir}_input_axial.log" \
        freeview -v \
        "$SUBJECTS_DIR/$subject/mri/orig.mgz" \
        "$SUBJECTS_PET_DIR/$subject/$pet_dir/gtmpvc_inf_cereb.output/rbv.nii.gz":colormap=heat:opacity=0.5 \
        "$SUBJECTS_BASE_DIR/$subject/mri/gtmseg+infcereb.mgz":colormap=lut:lut=$SCRIPT_DIR/infcereb.ctab:opacity=0.4 \
        --layout 1 --viewport axial \
        --screenshot "$output_dir/${subject}_${pet_dir}_input_axial.png" \
        --quit
    if [ $? -ne 0 ]; then
        echo "freeview input axial failed; log follows:" && cat "$output_dir/${subject}_${pet_dir}_input_axial.log" 1>&2
        return 1
    fi

    # Verify the PNG was created
    if [ ! -f "$output_dir/${subject}_${pet_dir}_input_axial.png" ]; then
        echo "Error: Failed to generate input axial PNG for $subject ($pet_dir)"
        return 1
    fi

    echo "QA images generated for $subject ($pet_dir)"

    # Create a PDF page for this subject using ImageMagick (2 rows instead of 3)
    montage \
        "$output_dir/${subject}_${pet_dir}_rbv_sagittal.png" "$output_dir/${subject}_${pet_dir}_rbv_coronal.png" "$output_dir/${subject}_${pet_dir}_rbv_axial.png" \
        "$output_dir/${subject}_${pet_dir}_input_sagittal.png" "$output_dir/${subject}_${pet_dir}_input_coronal.png" "$output_dir/${subject}_${pet_dir}_input_axial.png" \
        -tile 3x2 -geometry +5+5 \
        "$output_dir/${subject}_${pet_dir}_brain_grid.png"

    # Convert the montage to a centered PDF that fills the page
    convert -page 1300x800 "$output_dir/${subject}_${pet_dir}_brain_grid.png" "$output_dir/${subject}_${pet_dir}_PETqa.pdf"

    # Add after PDF creation
    if [ ! -s "$output_dir/${subject}_${pet_dir}_PETqa.pdf" ]; then
        echo "Error: Failed to create PDF for $subject ($pet_dir)"
        return 1
    fi

    echo "QA PDFs generated for $subject ($pet_dir)"
    mv "$output_dir/${subject}_${pet_dir}_PETqa.pdf" "$QA_DIR/${subject}_${pet_dir}_PETqa.pdf"
    rm -rf "$output_dir"
}

# Process each subject for each PET modality
process_subjects() {
    local pet_modality=$modality
    
    subject_base_dir="/data/subjects/$SUBJECT_ID"
    if [ -d "$subject_base_dir" ]; then
        subject=$(basename "$subject_base_dir")
        
        # Check if this subject has the specified PET modality
        if [ -d "$subject_base_dir/$pet_modality" ]; then
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