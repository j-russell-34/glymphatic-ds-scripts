import os
import nibabel as nib
import sys
import nilearn.image as img
import numpy as np
import pandas as pd
import ants

#import the subject id from the command line
subject = sys.argv[1]

flair_dir=f'/data/subjects_FLAIR/OUTPUTS/{subject}/samsegOutput'
alps_dir=f'/data/subjects_dti/OUTPUTS/{subject}/alps_output'
manual_rois=f'/data/OUTPUTS/{subject}/alps_output/manual_rois'
default_rois='/data/scripts/ROIs_JHU_ALPS'
atlas = ants.image_read('/data/scripts/wmh_comp/MNI152lin_T1_1mm_brain.nii.gz')
T1 = ants.image_read(f'{flair_dir}/T1.nii.gz')

#make dataframe with subject_id, voxel_overlap
df = pd.DataFrame(columns=["subject_id", "voxel_overlap"])

#identify if manual rois exist
if os.path.exists(f'{manual_rois}/L_SLF_bin.nii.gz'):
    L_SLF = nib.load(f'{manual_rois}/L_SLF_bin.nii.gz')
else:
    print("Manual ROIs not found, using default ROIs for comparison")
    L_SLF = nib.load(f'{default_rois}/L_SLF.nii.gz')

if os.path.exists(f'{manual_rois}/R_SLF_bin.nii.gz'):
    R_SLF = nib.load(f'{manual_rois}/R_SLF_bin.nii.gz')
else:
    print("Manual ROIs not found, using default ROIs for comparison")
    R_SLF = nib.load(f'{default_rois}/R_SLF.nii.gz')

if os.path.exists(f'{manual_rois}/L_SCR.nii.gz'):
    L_SCR = nib.load(f'{manual_rois}/L_SCR.nii.gz')
else:
    print("Manual ROIs not found, using default ROIs for comparison")
    L_SCR = nib.load(f'{default_rois}/L_SCR.nii.gz')

if os.path.exists(f'{manual_rois}/R_SCR.nii.gz'):
    R_SCR = nib.load(f'{manual_rois}/R_SCR.nii.gz')
else:
    print("Manual ROIs not found, using default ROIs for comparison")
    R_SCR = nib.load(f'{default_rois}/R_SCR.nii.gz')

#combine the ROIs
all_alps_rois = img.math_img('img1 + img2 + img3 + img4', img1=L_SLF, img2=R_SLF, img3=L_SCR, img4=R_SCR)

#load the lesion mask
lesion_mask = nib.load(f'{alps_dir}/wmh_lesion_mask.nii.gz')

#resample lesion mask to T1 space
lesion_mask_resampled = img.resample_to_img(lesion_mask, all_alps_rois, interpolation='nearest')

#save resampled lesion mask
nib.save(lesion_mask_resampled, f'{alps_dir}/wmh_lesion_mask_resampled.nii.gz')

lesion_mask_resampled = ants.image_read(f'{alps_dir}/wmh_lesion_mask_resampled.nii.gz')

#transform the T1 to MNI space
reg = ants.registration(fixed=atlas, moving=T1, type_of_transform='SyN')

#apply transform to lesion mask
lesion_mask_in_mni = ants.apply_transforms(fixed=atlas, moving=lesion_mask_resampled, transformlist=reg['fwdtransforms'])

#write out the lesion mask in MNI space
ants.image_write(lesion_mask_in_mni, f'{alps_dir}/wmh_lesion_mask_in_mni.nii.gz')

#load the lesion mask in MNI space
lesion_mask_in_mni = nib.load(f'{alps_dir}/wmh_lesion_mask_in_mni.nii.gz')

#convert lesion_mask_in_mni and all_alps_rois to numpy arrays
lesion_mask_in_mni_array = lesion_mask_in_mni.get_fdata()
all_alps_rois_array = all_alps_rois.get_fdata()

#ensure both arrays are binary
lesion_mask_in_mni_bin = (lesion_mask_in_mni_array > 0).astype(np.uint8)
all_alps_rois_bin = (all_alps_rois_array > 0).astype(np.uint8)

#count voxels present in both masks
voxels_in_both = np.logical_and(lesion_mask_in_mni_bin, all_alps_rois_bin)
num_voxels_in_both = np.sum(voxels_in_both)

#add to dataframe
new_row = pd.DataFrame({"subject_id": [subject], "voxel_overlap": [num_voxels_in_both]})
df = pd.concat([df, new_row], ignore_index=True)

#save dataframe
df.to_csv(f"{alps_dir}/alps_wmh_overlap.csv", index=False)
print("ALPS ROIs compared to WMH lesion mask")
