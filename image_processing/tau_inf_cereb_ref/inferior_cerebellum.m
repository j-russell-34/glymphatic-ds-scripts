function gen_inferior_cerebellum(subject_id, study)
    
    % Add paths to required toolboxes - added in slurm script
    %addpath('/data/software/matlab/spm12/');
    %addpath(genpath('/data/software/matlab/toolbox/'));
    spm('defaults', 'pet');
    
    display(['Isolating inferior cerebellum from ' subject_id]);

    %set data path
    image = 'image_reorient.nii';
    input = ['/project2/jasonkru_1564/studies/' study '/tau_inf_cereb_grey/subjects/' subject_id '/mri/orig'];
    fullpath = fullfile(input, image);

    %isolate cerebellum from nii
    suit_isolate_seg({fullpath});

    %normalize to suit space
    job.subjND(1).gray      = {fullfile(input, 'image_reorient_seg1.nii')};
    job.subjND(1).white     = {fullfile(input, 'image_reorient_seg2.nii')};
    job.subjND(1).isolation = {fullfile(input, 'c_image_reorient_pcereb.nii')};

    suit_normalize_dartel(job);

    job.subj.affineTr= {fullfile(input, 'Affine_image_reorient_seg1.mat')};
    job.subj.flowfield = {fullfile(input, 'u_a_image_reorient_seg1.nii')};
    job.subj.resample={fullfile(input, 'image_reorient.nii')};
    job.subj.mask={fullfile(input, 'c_image_reorient_pcereb.nii')};

    suit_reslice_dartel(job);

    %reslice inferior and superior cerebellum to subject space
    %path to probseg masks
    probseg_inferior = '/home1/jasonkru/atri_code/processors/tau_inf_cereb_ref/inferior_cerebellum_probmask.nii';
    probseg_superior = '/home1/jasonkru/atri_code/processors/tau_inf_cereb_ref/superior_cerebellum_probmask.nii';

    %reslice probseg masks to subject space
    job.Affine= {fullfile(input, 'Affine_image_reorient_seg1.mat')};
    job.flowfield = {fullfile(input, 'u_a_image_reorient_seg1.nii')};
    job.resample={probseg_inferior};
    job.ref={fullpath};

    %reslice probseg masks to subject space
    suit_reslice_dartel_inv(job);

    job2.Affine= {fullfile(input, 'Affine_image_reorient_seg1.mat')};
    job2.flowfield = {fullfile(input, 'u_a_image_reorient_seg1.nii')};
    job2.resample={probseg_superior};
    job2.ref={fullpath};

    %reslice probseg masks to subject space
    suit_reslice_dartel_inv(job2);

    %smooth probseg masks 8mm
    inferior_mask = fullfile(input, 'iw_inferior_cerebellum_probmask_u_a_image_reorient_seg1.nii');
    superior_mask = fullfile(input, 'iw_superior_cerebellum_probmask_u_a_image_reorient_seg1.nii');

    smooth_inferior = fullfile(input, 'smooth_inf_cerebellum_probmask.nii');
    smooth_superior = fullfile(input, 'smooth_sup_cerebellum_probmask.nii');

    spm_smooth(inferior_mask, smooth_inferior, [8 8 8]);
    spm_smooth(superior_mask, smooth_superior, [8 8 8]);

    display('Processing complete');





