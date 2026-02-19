from nipype.interfaces.io import SelectFiles, DataSink
from nipype.interfaces.spm import Segment, Normalize, Coregister
from nipype import Node, Workflow
import ants
import os
from os.path import join as opj
from nipype import IdentityInterface
import glob
from nilearn import image, masking, plotting
import numpy as np
import pandas as pd
from matplotlib.backends.backend_pdf import PdfPages
import matplotlib.pyplot as plt
import multiprocessing
from antspynet import brain_extraction
import sys

TRACER = sys.argv[2]

# Check if the subject ID is passed as an argument
if len(sys.argv) > 1:
    subject_id = sys.argv[1]
    print(f'Subject ID: {subject_id}')
else:
    print('No Subject ID provided.')
from nipype.interfaces import spm
matlab_cmd = '/opt/spm12/run_spm12.sh /opt/mcr/v97/ script'
spm.SPMCommand.set_mlab_paths(matlab_cmd=matlab_cmd, use_mcr=True)

in_dir = f'/data/subjects/{subject_id}'
out_dir = f'/data/centiloid/subjects/PROC_{TRACER}/{subject_id}'
atlas = '/data/scripts/atlases/avg152T1.nii'
ctx_voi = '/data/scripts/atlases/voi_ctx_2mm.nii'
wcbm_voi = '/data/scripts/atlases/voi_WhlCbl_2mm.nii'

#import ants atlas
mni = ants.image_read(atlas)

os.makedirs(out_dir, exist_ok=True)
    
subject_amyloid = glob.glob(f'{out_dir}/mean_pet.nii.gz')[0]
subject_mr = glob.glob(f'{in_dir}/mri/orig/*.nii.gz')[0]


print('Amyloid:', subject_amyloid)
print('MR:', subject_mr)

# Get full file path to input images
orig_file = subject_mr
amyloid_file = subject_amyloid


# Skull Strip Original T1 and mask
raw = ants.image_read(orig_file)
raw_pet = ants.image_read(amyloid_file)

# Add NaN cleaning
print("Checking for NaN values in images...")
raw_array = raw.numpy()
raw_pet_array = raw_pet.numpy()

# Replace NaN values with 0 in MRI
if np.any(np.isnan(raw_array)):
    print("Found NaN values in MRI, replacing with 0")
    raw_array[np.isnan(raw_array)] = 0
    raw = ants.from_numpy(raw_array, origin=raw.origin,
                         spacing=raw.spacing,
                         direction=raw.direction)

# Replace NaN values in PET
if np.any(np.isnan(raw_pet_array)):
    print("Found NaN values in PET, replacing with 0")
    raw_pet_array[np.isnan(raw_pet_array)] = 0
    raw_pet = ants.from_numpy(raw_pet_array, origin=raw_pet.origin,
                             spacing=raw_pet.spacing,
                             direction=raw_pet.direction)

moving = raw

#warp PET to MR
warp_pet = ants.registration(moving, raw_pet, type_of_transform='Rigid')

# Do Registration of Moving to Fixed
reg = ants.registration(mni, moving, type_of_transform='Rigid')

# Save warped orig
warped_orig_file = f'{out_dir}/reorient_mr.nii'
ants.image_write(reg['warpedmovout'], warped_orig_file)

# Apply transform to amyloid image which is already in same space
warped_amyloid_file = f'{out_dir}/reorient_pet.nii'
amyloid = warp_pet['warpedmovout']
warped_amyloid = ants.apply_transforms(mni, amyloid, reg['fwdtransforms'])
ants.image_write(warped_amyloid, warped_amyloid_file)


infosource = Node(IdentityInterface(fields=['subject_id']), name="infosource")


anat_file = 'reorient_mr.nii'
func_file = 'reorient_pet.nii'

templates = {
    'anat': anat_file,
    'func': func_file
    }

selectfiles = Node(SelectFiles(templates, 
                               base_directory= out_dir),
                   name="selectfiles")


# coreg
coreg_mr = Node(Coregister(), name="coreg_mr")
coreg_mr.jobtype = 'estwrite'
coreg_mr.inputs.target = atlas

coreg_pet = Node(Coregister(), name='coreg_pet')
coreg_pet.jobtype = 'estwrite'
coreg_pet.nonlinear_regularization = 1

#segmentation
segmentation = Node(Segment(), name="segmentation")

nan = float('nan')

#normalization
norm_write = Node(Normalize(), name = "norm_write")
norm_write.inputs.jobtype = 'write'
norm_write.inputs.write_bounding_box = [[nan, nan, nan], [nan, nan, nan]]
norm_write.inputs.write_voxel_sizes = [2, 2, 2]

#datasink
datasink = Node(DataSink(base_directory=out_dir),
                name = 'datasink')

#make workflow
cl_preproc = Workflow(name='cl_preproc', base_dir = out_dir)

cl_preproc.connect([
    (infosource, selectfiles, [('subject_id', 'subject_id')]),
    (selectfiles, coreg_mr, [('anat', 'source')]),
    (selectfiles, coreg_mr, [('anat', 'apply_to_files')]),
    (selectfiles, coreg_pet, [('func', 'source')]),
    (selectfiles, coreg_pet, [('func', 'apply_to_files')]),
    (coreg_mr, coreg_pet, [('coregistered_files', 'target')]),
    (coreg_mr, segmentation, [('coregistered_files', 'data')]),
    (segmentation, norm_write, [('transformation_mat', 'parameter_file')]),
    (coreg_pet, norm_write, [('coregistered_files', 'apply_to_files')]),
    (coreg_mr, datasink, [('coregistered_files', 'normalized_mr1')]),
    (coreg_pet, datasink, [('coregistered_files', 'normalized_pet1')]),
    (norm_write, datasink, [('normalized_files', 'normalized_final')])
])

if __name__ == '__main__':
    multiprocessing.set_start_method('fork')
    cl_preproc.run('MultiProc', plugin_args={'n_procs': 4})

#calculate SUVR and apply to df
# suvr_value = ctx_stats.result.outputs.out_stat / wcbm_stats.result.outputs.out_stat
output_df = pd.DataFrame(columns=['ID', 'SUVR'])

 #apply masks
pet_mni = f'{out_dir}/cl_preproc/norm_write/wrreorient_pet.nii'
    
ctx_masked = masking.apply_mask(pet_mni, ctx_voi)
wcbm_masked = masking.apply_mask(pet_mni, wcbm_voi)
    
# Calculate the mean uptake in the VOIs
mean_uptake_voi = ctx_masked.mean()
mean_uptake_ref = wcbm_masked.mean()
    
suvr = mean_uptake_voi/mean_uptake_ref
    

row = [subject_id, suvr]
    
output_df.loc[len(output_df)] = row
    
# Generate pdf report
pdf_filename = f"{out_dir}/{subject_id}_report.pdf"

with PdfPages(pdf_filename) as pdf:
    fig, axs = plt.subplots(3, 1, figsize=(10,14))
    subject_name = subject_id
           
    img = image.load_img(f'{out_dir}/cl_preproc/norm_write/wrreorient_pet.nii')
        
    plotting.plot_roi(
        img,
        figure=fig,
        title = f"{subject_name} PET transform to MNI",
        axes=axs[0]
    )
        
    plotting.plot_roi(
        ctx_voi,
        img,
        figure=fig,
        title = f"{subject_name} PET transform with ctx VOI overlay",
        axes=axs[1]
    )
        
    plotting.plot_roi(
        wcbm_voi,
        img,
        figure=fig,
        title = f"{subject_name} PET transform with cblm VOI overlay",
        axes=axs[2]
    )
        
    pdf.savefig(fig, dpi=300)
    plt.close(fig)
    
output_df.to_csv(f'{out_dir}/{subject_id}_{TRACER}_standard_centiloid_suvr.csv', index=False)
