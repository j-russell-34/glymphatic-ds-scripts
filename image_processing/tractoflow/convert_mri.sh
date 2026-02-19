#!bin/bash


echo "Converting mri to nii"
mri_convert /data/t1.mgz /data/t1.nii.gz
mri_convert /data/aparc+aseg.mgz /data/aparc+aseg.nii.gz
mri_convert /data/wmparc.mgz /data/wmparc.nii.gz
echo "MRI converted to nii"