#!/bin/bash

# Enable error handling
set -e

#import subject id
subject_id=$1
subject_dir=/data/$subject_id/dti_files

output=/data/OUTPUTS/${subject_id}/alps_output/manual_rois
#set json file to image*.json or image.json

# JSON file detection
json1=$(find "$subject_dir" -name "image*.json" | head -1)
if [ -z "$json1" ] && [ -f "$subject_dir/image.json" ]; then
    json1="$subject_dir/image.json"
fi

# Check if JSON file was found
if [ -z "$json1" ] || [ ! -f "$json1" ]; then
    echo "Error: No JSON file found in $subject_dir"
    exit 1
fi

scanner1=$(cat "${json1}" | awk -F'"' '/"Manufacturer"/ {print $4}')

mkdir -p ${output}

#set path to assoc rois
#check if L_SLF_bin.nii.gz and R_SLF_bin.nii.gz exist in output directory
if [ -f ${output}/L_SLF_bin.nii.gz ] && [ -f ${output}/R_SLF_bin.nii.gz ]; then
    assoc_l_roi=${output}/L_SLF_bin.nii.gz
    assoc_r_roi=${output}/R_SLF_bin.nii.gz
else
    assoc_l_roi=/data/scripts/ROIs_JHU_ALPS/L_SLF.nii.gz
    assoc_r_roi=/data/scripts/ROIs_JHU_ALPS/R_SLF.nii.gz
fi

# Check if association ROI files exist
if [ ! -f "$assoc_l_roi" ] || [ ! -f "$assoc_r_roi" ]; then
    echo "Error: Association ROI files not found: $assoc_l_roi or $assoc_r_roi"
    exit 1
fi

#check if subject is in the csv file
csv_file=/data/scripts/rois.csv
csv_row=$(grep "^${subject_id}," "$csv_file")
if [ -z "$csv_row" ]; then
    echo "Subject ${subject_id} not found in CSV file, using default ROIs"
    proj_L=/data/scripts/ROIs_JHU_ALPS/L_SCR.nii.gz
    proj_R=/data/scripts/ROIs_JHU_ALPS/R_SCR.nii.gz
    
    # Check if default ROI files exist
    if [ ! -f "$proj_L" ] || [ ! -f "$proj_R" ]; then
        echo "Error: Default projection ROI files not found: $proj_L or $proj_R"
        exit 1
    fi
else
    #generate proj ROIs
    #set L and R co-ordinates from input csv

    # Extract coordinates for the current subject from CSV
    # CSV format: subject, left_x, left_y, left_z, right_x, right_y, right_z
    csv_row=$(grep "^${subject_id}," "$csv_file")

    # Parse the CSV row and assign to variables
    IFS=',' read -r subj left_x left_y left_z right_x right_y right_z <<< "$csv_row"


    # Verify correct sub
    if [ "$subj" != "$subject_id" ]; then
        echo "Error: Subject mismatch - expected ${subject_id}, got ${subj}"
        exit 1
    fi


    echo "Coordinates for subject ${subject_id}:"
    echo "Left: (${left_x}, ${left_y}, ${left_z})"
    echo "Right: (${right_x}, ${right_y}, ${right_z})"


    proj25_l_roi=/data/scripts/ROIs_JHU_ALPS/L_SCR.nii.gz
    proj25_r_roi=/data/scripts/ROIs_JHU_ALPS/R_SCR.nii.gz

    # Check if template ROI files exist
    if [ ! -f "$proj25_l_roi" ] || [ ! -f "$proj25_r_roi" ]; then
        echo "Error: Template projection ROI files not found: $proj25_l_roi or $proj25_r_roi"
        exit 1
    fi

    fslmaths ${proj25_l_roi} -mul 0 -add 1 -roi ${left_x} 1 ${left_y} 1 ${left_z} 1 0 1 ${output}/proj_l -odt float
    fslmaths ${proj25_r_roi} -mul 0 -add 1 -roi ${right_x} 1 ${right_y} 1 ${right_z} 1 0 1 ${output}/proj_r -odt float

    fslmaths ${output}/proj_l -kernel sphere 2.5 -fmean ${output}/proj_l_sphere -odt float
    fslmaths ${output}/proj_r -kernel sphere 2.5 -fmean ${output}/proj_r_sphere -odt float

    fslmaths ${output}/proj_l_sphere -bin ${output}/L_SCR.nii.gz
    fslmaths ${output}/proj_r_sphere -bin ${output}/R_SCR.nii.gz
    
    # Check if generated ROI files exist
    if [ ! -f "${output}/L_SCR.nii.gz" ] || [ ! -f "${output}/R_SCR.nii.gz" ]; then
        echo "Error: Failed to generate projection ROI files"
        exit 1
    fi

    proj_L=${output}/L_SCR.nii.gz
    proj_R=${output}/R_SCR.nii.gz
fi

outdir=/data/OUTPUTS/${subject_id}/alps_output
template_abbreviation=JHU-FA

#calculate alps from new rois
dxx="${outdir}/dxx_in_${template_abbreviation}.nii.gz"
dyy="${outdir}/dyy_in_${template_abbreviation}.nii.gz"
dzz="${outdir}/dzz_in_${template_abbreviation}.nii.gz"
fa="${outdir}/dti_FA_to_${template_abbreviation}.nii.gz"
md="${outdir}/dti_MD_to_${template_abbreviation}.nii.gz"

# Check if all required input files exist
required_files=("$dxx" "$dyy" "$dzz" "$fa" "$md")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required file not found: $file"
        exit 1
    fi
done

#GATHER STATS
mkdir -p "${output}/alps.stat"
echo "id,scanner,x_proj_L,x_assoc_L,y_proj_L,z_assoc_L,x_proj_R,x_assoc_R,y_proj_R,z_assoc_R,alps_L,alps_R,alps" > "${output}/alps.stat/alps.csv"
echo "id,scanner,diffusion_metric,proj_L,assoc_L,proj_R,assoc_R,mean_proj,mean_assoc" > "${output}/alps.stat/fa+md_alps.csv"

id=${subject_id}


assoc_L=$assoc_l_roi
assoc_R=$assoc_r_roi

# Check if all ROI files exist before processing
if [ ! -f "$proj_L" ] || [ ! -f "$proj_R" ] || [ ! -f "$assoc_L" ] || [ ! -f "$assoc_R" ]; then
    echo "Error: One or more ROI files not found:"
    echo "  proj_L: $proj_L"
    echo "  proj_R: $proj_R"
    echo "  assoc_L: $assoc_L"
    echo "  assoc_R: $assoc_R"
    exit 1
fi

# Calculate ALPS metrics
echo "Calculating ALPS metrics..."
x_proj_L="$(fslstats "${dxx}" -k "${proj_L}" -m)"
x_assoc_L="$(fslstats "${dxx}" -k "${assoc_L}" -m)"
y_proj_L="$(fslstats "${dyy}" -k "${proj_L}" -m)"
z_assoc_L="$(fslstats "${dzz}" -k "${assoc_L}" -m)"
x_proj_R="$(fslstats "${dxx}" -k "${proj_R}" -m)"
x_assoc_R="$(fslstats "${dxx}" -k "${assoc_R}" -m)"
y_proj_R="$(fslstats "${dyy}" -k "${proj_R}" -m)"
z_assoc_R="$(fslstats "${dzz}" -k "${assoc_R}" -m)"

# Check calcs
if [ -z "$x_proj_L" ] || [ -z "$x_assoc_L" ] || [ -z "$y_proj_L" ] || [ -z "$z_assoc_L" ] || \
   [ -z "$x_proj_R" ] || [ -z "$x_assoc_R" ] || [ -z "$y_proj_R" ] || [ -z "$z_assoc_R" ]; then
    echo "Error: One or more fslstats calculations failed"
    exit 1
fi

alps_L=`echo "(($x_proj_L+$x_assoc_L)/2)/(($y_proj_L+$z_assoc_L)/2)" | bc -l` #proj1 and assoc1 are left side, bc -l needed for decimal printing results
alps_R=`echo "(($x_proj_R+$x_assoc_R)/2)/(($y_proj_R+$z_assoc_R)/2)" | bc -l` #proj2 and assoc2 are right side, bc -l needed for decimal printing results
alps=`echo "($alps_R+$alps_L)/2" | bc -l`

# Check ALPS calculations
if [ -z "$alps_L" ] || [ -z "$alps_R" ] || [ -z "$alps" ]; then
    echo "Error: ALPS calculations failed"
    exit 1
fi

echo "ALPS calculations completed successfully:"
echo "  ALPS_L: $alps_L"
echo "  ALPS_R: $alps_R"
echo "  ALPS: $alps"

echo "${id},${scanner1},${x_proj_L},${x_assoc_L},${y_proj_L},${z_assoc_L},${x_proj_R},${x_assoc_R},${y_proj_R},${z_assoc_R},${alps_L},${alps_R},${alps}" >> "${output}/alps.stat/alps.csv"

#FA and MD values from projection and association areas
echo "Calculating FA and MD values..."
for diff in "${fa}" "${md}"; do
    pl="$(fslstats "${diff}" -k "${proj_L}" -m)"
    pr="$(fslstats "${diff}" -k "${proj_R}" -m)"
    al="$(fslstats "${diff}" -k "${assoc_L}" -m)"
    ar="$(fslstats "${diff}" -k "${assoc_R}" -m)"
    
    # Check if FA/MD calculations produced valid results
    if [ -z "$pl" ] || [ -z "$pr" ] || [ -z "$al" ] || [ -z "$ar" ]; then
        echo "Error: FA/MD calculations failed for $(basename "$diff")"
        exit 1
    fi
    
    pmean=`echo "($pl+$pr)/2" | bc -l`
    amean=`echo "($al+$ar)/2" | bc -l`
    if [ "${diff}" == "${fa}" ]; then d="FA"; else d="MD"; fi
    echo "${id},${scanner1},${d},${pl},${al},${pr},${ar},${pmean},${amean}" >> "${outdir}/alps.stat/fa+md_alps.csv"
done

echo "Successfully generated alps.csv and fa+md_alps.csv files"
echo "Output directory: ${output}/alps.stat/"