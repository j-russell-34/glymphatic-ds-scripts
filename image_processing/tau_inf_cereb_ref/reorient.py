import nibabel as nib
import numpy as np
import os
from nilearn.image import resample_to_img
import ants
import glob

#Get SLURM_ARRAY_TASK_ID from environment variables
task_id = os.environ.get('SLURM_ARRAY_TASK_ID')

# Read subject list to get the current subject
subject_list_file = "/data/cblm_subject_list.txt"
subject_dir="/data/tau_inf_cereb_grey/subjects"

#Using ants move MRI rigidly to MNI space and save transforms
atlas = '/data/scripts/atlases/avg152T1.nii'


#import ants atlas
mni = ants.image_read(atlas)


try:
    with open(subject_list_file, 'r') as f:
        subject_lines = f.readlines()
    
    # Get the subject based on the task ID (convert to int and subtract 1 for zero-indexing)
    subject_id = subject_lines[int(task_id) - 1].strip()
    print(f"Processing subject: {subject_id}")
    
    out_dir = f'/data/tau_inf_cereb_grey/subjects/{subject_id}/mri/orig'
    in_dir = f'/data/tau_inf_cereb_grey/subjects/{subject_id}/mri/orig'

    
    subject_mr = glob.glob(f'{in_dir}/image_ras.nii')[0]

    print('MR:', subject_mr)

    # Get full file path to input images
    orig_file = subject_mr
    raw = ants.image_read(orig_file)

    # Do reorientation of Moving to Fixed
    reg = ants.registration(mni, raw, type_of_transform='Rigid')

    moving = raw

    # Save the transformation matrix
    transform_file = f'{out_dir}/rigid_transform.mat'
    tx = ants.read_transform(reg['fwdtransforms'][0])
    ants.write_transform(tx, transform_file)
    print(f"Saved transformation matrix to: {transform_file}")

    # Save warped orig
    warped_orig_file = f'{out_dir}/image_reorient.nii'
    ants.image_write(reg['warpedmovout'], warped_orig_file)

except Exception as e:
    print(f"Error reorienting subject {subject_id}: {e}")
    raise