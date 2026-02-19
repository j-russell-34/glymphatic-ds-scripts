import nibabel as nib
import numpy as np
import os
from nilearn.image import resample_to_img
import ants

# Get SLURM_ARRAY_TASK_ID from environment variables
task_id = os.environ.get('SLURM_ARRAY_TASK_ID')

# Read subject list to get the current subject
subject_list_file = "/data/cblm_subject_list.txt"
subject_dir="/data/tau_inf_cereb_grey/subjects"

try:
    with open(subject_list_file, 'r') as f:
        subject_lines = f.readlines()
    
    # Get the subject based on the task ID (convert to int and subtract 1 for zero-indexing)
    subject_id = subject_lines[int(task_id) - 1].strip()
    print(f"Processing subject: {subject_id}")

    # set paths
    subject_mri_path = f'{subject_dir}/{subject_id}/mri'

    # Get path to transform file
    transform_path = f'{subject_mri_path}/orig/rigid_transform.mat'

    # Load images
    ants_inf_img = ants.image_read(f'{subject_mri_path}/orig/smooth_inf_cerebellum_probmask.nii')
    ants_sup_img = ants.image_read(f'{subject_mri_path}/orig/smooth_sup_cerebellum_probmask.nii')
    ants_gm_mask_img = ants.image_read(f'{subject_mri_path}/cerebellar_gm_mask.nii.gz')

    #reverse transforms inf and sup masks
    inf_img = ants.apply_transforms(fixed=ants_gm_mask_img, moving=ants_inf_img, transformlist=[transform_path], whichtoinvert=[True])
    sup_img = ants.apply_transforms(fixed=ants_gm_mask_img, moving=ants_sup_img, transformlist=[transform_path], whichtoinvert=[True])

    #save the transformed images
    ants.image_write(inf_img, f'{subject_mri_path}/orig/smooth_inf_cerebellum_probmask_inv_reorient.nii')
    ants.image_write(sup_img, f'{subject_mri_path}/orig/smooth_sup_cerebellum_probmask_inv_reorient.nii')

    #load transformed images with nib
    inf_img = nib.load(f'{subject_mri_path}/orig/smooth_inf_cerebellum_probmask_inv_reorient.nii')
    sup_img = nib.load(f'{subject_mri_path}/orig/smooth_sup_cerebellum_probmask_inv_reorient.nii')
    gm_mask_img = nib.load(f'{subject_mri_path}/cerebellar_gm_mask.nii.gz')


    #resample smoothed suit masks to cblm gm mask
    inf_img = resample_to_img(inf_img, gm_mask_img)
    sup_img = resample_to_img(sup_img, gm_mask_img)
    
    # Load data
    inf_data = inf_img.get_fdata()
    sup_data = sup_img.get_fdata()
    gm_mask = gm_mask_img.get_fdata() > 0  # binary mask

    # Apply logic
    new_mask = (inf_data > sup_data) & gm_mask

    # Save new mask (in LIA orientation)
    new_mask_img = nib.Nifti1Image(new_mask.astype(np.uint8), gm_mask_img.affine, gm_mask_img.header)
    nib.save(new_mask_img, f'{subject_mri_path}/final_inferior_cerebellar_mask.nii.gz')

except Exception as e:
    print(f"Error processing subject {subject_id}: {e}")
    raise

