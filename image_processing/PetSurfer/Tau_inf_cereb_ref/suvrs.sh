#!/bin/bash

# Set up environment variables for container paths
SUBJECTS_BASE_DIR="/data/processed_mri/subjects"
SUBJECT_LIST_FILE="/data/tau_subject_list.txt"
SUBJECTS_PET_DIR="/data/tau_inf_cereb_grey/subjects"


# Get the subject ID from the list file using the SLURM_ARRAY_TASK_ID
SUBJECT_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SUBJECT_LIST_FILE")

if [ -z "$SUBJECT_ID" ]; then
    echo "Error: Could not find subject ID for task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

# Extract the subject ID without the event flag (_eX)
sub_no_ev="${SUBJECT_ID%%_e*}"

if [ -z "$2" ]; then
    echo "Error: RADIOTRACER not provided"
    exit 1
fi

RADIOTRACER="$2"

echo "Calculating Braak ROIs for: $SUBJECT_ID"
echo "Subject ID without event flag: $sub_no_ev"

# ROI's from: https://adni.bitbucket.io/reference/docs/UCBERKELEYAV1451/UCBERKELEY_AV1451_Methods_Aug2018.pdf
# Generate the braak stage 1 ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz" \
--match 1006 2006 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak1_icref_full.nii.gz"

# Match bounding box to RBV output
mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak1_icref_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak1_icref.nii.gz"

# Clean up temporary file
rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak1_icref_full.nii.gz"

# Generate the braak stage 2 ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz" \
--match 17 53 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak2_icref_full.nii.gz"

mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak2_icref_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak2_icref.nii.gz"

rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak2_icref_full.nii.gz"

# Generate the braak stage 3 ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz" \
--match 1016 1007 1013 18 2016 2007 2013 54 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak3_icref_full.nii.gz"

mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak3_icref_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak3_icref.nii.gz"

rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak3_icref_full.nii.gz"

# Generate the braak stage 4 ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz" \
--match 1015 1002 1026 1023 1010 1035 1009 1033 2015 2002 2026 2023 2010 2035 2009 2033 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak4_icref_full.nii.gz"

mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak4_icref_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak4_icref.nii.gz"

rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak4_icref_full.nii.gz"

# Generate the braak stage 5 ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz" \
--match 1028 1012 1014 1032 1003 1027 1018 1019 1020 1011 1031 1009 1030 1029 1025 1001 1034 2028 2012 2014 2032 2003 2027 2018 2019 2020 2011 2031 2008 2030 2029 2025 2001 2034 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak5_icref_full.nii.gz"

mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak5_icref_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak5_icref.nii.gz"

rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak5_icref_full.nii.gz"

# Generate the braak stage 6 ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz" \
--match 1021 1022 1005 1024 1017 2021 2022 2005 2024 2017 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak6_icref_full.nii.gz"

mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak6_icref_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak6_icref.nii.gz"

rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak6_icref_full.nii.gz"

# Generate the braak stage 12 composite ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz" \
--match 1006 2006 17 53 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak12_composite_icref_full.nii.gz"

mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak12_composite_icref_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak12_composite_icref.nii.gz"

rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak12_composite_icref_full.nii.gz"

# Generate the braak stage 34 composite ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz" \
--match 1016 1007 1013 18 2016 2007 2013 54 1015 1002 1026 1023 1010 1035 1009 1033 2015 2002 2026 2023 2010 2035 2009 2033 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak34_composite_icref_full.nii.gz"

mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak34_composite_icref_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak34_composite_icref.nii.gz"

rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak34_composite_icref_full.nii.gz"

# Generate the braak stage 56 composite ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz" \
--match 1028 1012 1014 1032 1003 1027 1018 1019 1020 1011 1031 1009 1030 1029 1025 1001 1034 2028 2012 2014 2032 2003 2027 2018 2019 2020 2011 2031 2008 2030 2029 2025 2001 2034 1021 1022 1005 1024 1017 2021 2022 2005 2024 2017 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak56_composite_icref_full.nii.gz"

mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak56_composite_icref_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak56_composite_icref.nii.gz"

rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak56_composite_icref_full.nii.gz"

#generate metatemporal ROI
mri_binarize \
--i "${SUBJECTS_BASE_DIR}/${SUBJECT_ID}/mri/gtmseg+infcereb_long.mgz" \
--match 1006 2006 18 54 1016 2016 1007 2007 1009 2009 1015 2015 \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/metatemporal_icref_full.nii.gz"

mri_vol2vol \
--mov "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/metatemporal_icref_full.nii.gz" \
--targ "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" \
--regheader \
--o "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/metatemporal_icref.nii.gz"

rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/metatemporal_icref_full.nii.gz"



#calculate the suvr for each braak ROI
#Braak 1
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak1_icref.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak1_icref_stats.txt"

#Braak 2
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak2_icref.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak2_icref_stats.txt"

#Braak 3
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak3_icref.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak3_icref_stats.txt"

#Braak 4
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak4_icref.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak4_icref_stats.txt"

#Braak 5
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak5_icref.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak5_icref_stats.txt"

#Braak 6
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak6_icref.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak6_icref_stats.txt"

#Braak 12 composite
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak12_composite_icref.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak12_composite_icref_stats.txt"

#Braak 34 composite
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak34_composite_icref.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak34_composite_icref_stats.txt"

#Braak 56 composite
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak56_composite_icref.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak56_composite_icref_stats.txt"

#Metatemporal
mri_segstats --seg "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/metatemporal_icref.nii.gz" --id 1 --i "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/gtmpvc_inf_cereb.output/rbv.long.nii.gz" --avgwf "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/metatemporal_icref_stats.txt"

# Create the combined stats file with headers
echo -e "Region\tSUVR" > "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak_icref_stats.txt"

# Combine all stats, adding region names
for region in braak1 braak2 braak3 braak4 braak5 braak6 braak12_composite braak34_composite braak56_composite metatemporal; do
    value=$(cat "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/${region}_icref_stats.txt")
    echo -e "${region}\t${value}" >> "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak_icref_allstats.txt"
done

# Optional: Clean up individual stats files
rm "${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/"*_icref_stats.txt

echo "Braak ROIs calculated for: $SUBJECT_ID, stats saved to ${SUBJECTS_PET_DIR}/${SUBJECT_ID}/${RADIOTRACER}/braak_icref_allstats.txt"
