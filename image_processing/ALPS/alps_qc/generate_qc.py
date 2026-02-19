import os
import sys
from nilearn.plotting import plot_anat
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from scipy.ndimage import center_of_mass
from nilearn.image import load_img
import numpy as np

#get subject_id passed in as an argument
subject_id = sys.argv[1]


#get the path to the subject's data in qc output
subject_path = f"/data/OUTPUTS/{subject_id}/alps_output"
qc_output_path = f"/data/OUTPUTS/ALPS_QC"
rois_path = f"/data/OUTPUTS/{subject_id}/alps_output"

#get path to FA image and masks
color_fa = f"{subject_path}/color_fa/dti_color_fa.nii.gz"
l_scr = f"{rois_path}/L_SCR_in_JHU-FA.nii.gz"
r_scr = f"{rois_path}/R_SCR_in_JHU-FA.nii.gz"
l_slf = f"{rois_path}/L_SLF_in_JHU-FA.nii.gz"
r_slf = f"{rois_path}/R_SLF_in_JHU-FA.nii.gz"

l_scr_img = load_img(l_scr)
l_scr_data = l_scr_img.get_fdata()
l_scr_affine = l_scr_img.affine

#get the center of mass of the roi
_xlscr,_ylscr,_zlscr = center_of_mass(l_scr_data, labels=l_scr_data, index=1)

r_scr_img = load_img(r_scr)
r_scr_data = r_scr_img.get_fdata()
r_scr_affine = r_scr_img.affine

#get the center of mass of the roi
_xrscr,_yrscr,_zrscr = center_of_mass(r_scr_data, labels=r_scr_data, index=1)

l_slf_img = load_img(l_slf)
l_slf_data = l_slf_img.get_fdata()
l_slf_affine = l_slf_img.affine

#get the center of mass of the roi
_xlslf,_ylslf,_zlslf = center_of_mass(l_slf_data, labels=l_slf_data, index=1)

r_slf_img = load_img(r_slf)
r_slf_data = r_slf_img.get_fdata()
r_slf_affine = r_slf_img.affine

#get the center of mass of the roi
_xrslf,_yrslf,_zrslf = center_of_mass(r_slf_data, labels=r_slf_data, index=1)

#load the FA image
color_fa_img = load_img(color_fa)

# Generate pdf report
pdf_filename = f"{qc_output_path}/{subject_id}_ALPS_QC.pdf"


with PdfPages(pdf_filename) as pdf:
    print("Adding color FA visualization with ROI overlays...")

    color_fa_data = color_fa_img.get_fdata()
    
    # Define the ROIs and their centers of mass
    roi_centers = [
        ("L_SCR", (_xlscr, _ylscr, _zlscr)),
        ("R_SCR", (_xrscr, _yrscr, _zrscr)),
        ("L_SLF", (_xlslf, _ylslf, _zlslf)),
        ("R_SLF", (_xrslf, _yrslf, _zrslf))
    ]
    
    # Create a page for each ROI
    for roi_name, (x_center, y_center, z_center) in roi_centers:
        print(f"Creating page for {roi_name}...")
        
        # Create a new figure for each ROI
        fig_color = plt.figure(figsize=(15, 12), facecolor='black')
        fig_color.suptitle(f'ALPS Color FA: {subject_id} - {roi_name}', fontsize=16, color='white', y=0.95)

        # Create subplots for different views (2 rows, 3 columns)
        ax_color_axial = plt.subplot(2, 3, 1, facecolor='black')
        ax_color_coronal = plt.subplot(2, 3, 2, facecolor='black')
        ax_color_sagittal = plt.subplot(2, 3, 3, facecolor='black')
        
        # New row for individual RGB channels in axial view
        ax_r_channel = plt.subplot(2, 3, 4, facecolor='black')
        ax_g_channel = plt.subplot(2, 3, 5, facecolor='black')
        ax_b_channel = plt.subplot(2, 3, 6, facecolor='black')

        # Get the slice coordinates based on this ROI's center of mass
        z_slice = int(z_center)
        y_slice = int(y_center)
        x_slice = int(x_center)

        # Extract RGB channels
        r_channel = color_fa_data[:, :, z_slice, 0]  # Red (Left-Right)
        g_channel = color_fa_data[:, :, z_slice, 1]  # Green (Anterior-Posterior)
        b_channel = color_fa_data[:, :, z_slice, 2]  # Blue (Superior-Inferior)

        # Create RGB image by combining channels
        rgb_slice = np.stack([r_channel, g_channel, b_channel], axis=-1)

        # Normalize each channel for better visualization
        rgb_normalized = np.zeros_like(rgb_slice)
        for i in range(3):
            channel = rgb_slice[:, :, i]
            max_val = np.max(channel)
            if max_val > 0:
                rgb_normalized[:, :, i] = channel / max_val

        # Create layered color image (blue base, green 80% opacity, red 10% opacity)
        layered_slice = np.zeros_like(rgb_normalized)
        
        # Blue channel as base (full opacity)
        layered_slice[:, :, 2] = rgb_normalized[:, :, 2]
        
        # Green channel with 80% opacity
        layered_slice[:, :, 1] = rgb_normalized[:, :, 1] * 0.8
        
        # Red channel with 50% opacity 
        layered_slice[:, :, 0] = rgb_normalized[:, :, 0] * 0.5

        # Plot layered color image (axial) with ROI overlays
        ax_color_axial.imshow(np.rot90(layered_slice, k=3), origin='lower')
        ax_color_axial.axis('off') 
        ax_color_axial.set_title('Axial', color='white', fontsize=12)

        # Add ROI overlays to axial slice
        rois = [l_scr_img, r_scr_img, l_slf_img, r_slf_img]
        colors = ['red', 'red', 'blue', 'blue']
        for i, (roi, color) in enumerate(zip(rois, colors)):
            try:
                roi_data = roi.get_fdata()
                roi_slice = roi_data[:, :, z_slice]
                if np.any(roi_slice > 0):
                    roi_slice_rotated = np.rot90(roi_slice, k=3)  # k=3 for 270° rotation
                    ax_color_axial.contour(roi_slice_rotated, colors=color, linewidths=1.5, alpha=0.9)
            except Exception as e:
                print(f"Error adding ROI {i+1} to color FA axial: {e}")

        # Add coronal and sagittal views with ROI overlays
        # Coronal (Y slice)
        rgb_coronal = np.stack([
            color_fa_data[:, y_slice, :, 0],
            color_fa_data[:, y_slice, :, 1], 
            color_fa_data[:, y_slice, :, 2]
        ], axis=-1)

        # Normalize
        for i in range(3):
            channel = rgb_coronal[:, :, i]
            max_val = np.max(channel)
            if max_val > 0:
                rgb_coronal[:, :, i] = channel / max_val

        # Create layered color image for coronal view
        layered_coronal = np.zeros_like(rgb_coronal)
        
        # Blue channel as base (full opacity)
        layered_coronal[:, :, 2] = rgb_coronal[:, :, 2]
        
        # Green channel with 80% opacity
        layered_coronal[:, :, 1] = rgb_coronal[:, :, 1] * 0.8
        
        # Red channel with 50% opacity
        layered_coronal[:, :, 0] = rgb_coronal[:, :, 0] * 0.5

        ax_color_coronal.imshow(np.rot90(layered_coronal, k=3), origin='lower')
        ax_color_coronal.axis('off')
        ax_color_coronal.set_title('Coronal', color='white', fontsize=12)

        # Add ROI overlays to coronal slice
        for i, (roi, color) in enumerate(zip(rois, colors)):
            try:
                roi_data = roi.get_fdata()
                roi_slice = roi_data[:, y_slice, :]
                if np.any(roi_slice > 0):
                    roi_slice_rotated = np.rot90(roi_slice, k=3)
                    ax_color_coronal.contour(roi_slice_rotated, colors=color, linewidths=1.5, alpha=0.9)
            except Exception as e:
                print(f"Error adding ROI {i+1} to color FA coronal: {e}")

        # Sagittal (X slice)
        rgb_sagittal = np.stack([
            color_fa_data[x_slice, :, :, 0],
            color_fa_data[x_slice, :, :, 1],
            color_fa_data[x_slice, :, :, 2]
        ], axis=-1)

        # Normalize
        for i in range(3):
            channel = rgb_sagittal[:, :, i]
            max_val = np.max(channel)
            if max_val > 0:
                rgb_sagittal[:, :, i] = channel / max_val

        # Create layered color image for sagittal view
        layered_sagittal = np.zeros_like(rgb_sagittal)
        
        # Blue channel as base (full opacity)
        layered_sagittal[:, :, 2] = rgb_sagittal[:, :, 2]
        
        # Green channel with 80% opacity
        layered_sagittal[:, :, 1] = rgb_sagittal[:, :, 1] * 0.8
        
        # Red channel with 50% opacity
        layered_sagittal[:, :, 0] = rgb_sagittal[:, :, 0] * 0.5

        ax_color_sagittal.imshow(np.rot90(layered_sagittal, k=3), origin='lower')
        ax_color_sagittal.axis('off')
        ax_color_sagittal.set_title('Sagittal', color='white', fontsize=12)

        # Add ROI overlays to sagittal slice
        for i, (roi, color) in enumerate(zip(rois, colors)):
            try:
                roi_data = roi.get_fdata()
                roi_slice = roi_data[x_slice, :, :]
                if np.any(roi_slice > 0):
                    roi_slice_rotated = np.rot90(roi_slice, k=3)
                    ax_color_sagittal.contour(roi_slice_rotated, colors=color, linewidths=1.5, alpha=0.9)
            except Exception as e:
                print(f"Error adding ROI {i+1} to color FA sagittal: {e}")

        # Now add individual RGB channels in axial view
        # Red channel (Left-Right)
        r_channel_axial = color_fa_data[:, :, z_slice, 0]
        r_channel_norm = r_channel_axial / np.max(r_channel_axial) if np.max(r_channel_axial) > 0 else r_channel_axial
        ax_r_channel.imshow(np.rot90(r_channel_norm, k=3), cmap='Reds', origin='lower')
        ax_r_channel.axis('off')
        ax_r_channel.set_title('Red Channel (L-R)', color='white', fontsize=12)
        
        # Add ROI overlays to red channel
        for i, (roi, color) in enumerate(zip(rois, colors)):
            try:
                roi_data = roi.get_fdata()
                roi_slice = roi_data[:, :, z_slice]
                if np.any(roi_slice > 0):
                    roi_slice_rotated = np.rot90(roi_slice, k=3)
                    ax_r_channel.contour(roi_slice_rotated, colors=color, linewidths=1.5, alpha=0.9)
            except Exception as e:
                print(f"Error adding ROI {i+1} to red channel: {e}")

        # Green channel (Anterior-Posterior)
        g_channel_axial = color_fa_data[:, :, z_slice, 1]
        g_channel_norm = g_channel_axial / np.max(g_channel_axial) if np.max(g_channel_axial) > 0 else g_channel_axial
        ax_g_channel.imshow(np.rot90(g_channel_norm, k=3), cmap='Greens', origin='lower')
        ax_g_channel.axis('off')
        ax_g_channel.set_title('Green Channel (A-P)', color='white', fontsize=12)
        
        # Add ROI overlays to green channel
        for i, (roi, color) in enumerate(zip(rois, colors)):
            try:
                roi_data = roi.get_fdata()
                roi_slice = roi_data[:, :, z_slice]
                if np.any(roi_slice > 0):
                    roi_slice_rotated = np.rot90(roi_slice, k=3)
                    ax_g_channel.contour(roi_slice_rotated, colors=color, linewidths=1.5, alpha=0.9)
            except Exception as e:
                print(f"Error adding ROI {i+1} to green channel: {e}")

        # Blue channel (Superior-Inferior)
        b_channel_axial = color_fa_data[:, :, z_slice, 2]
        b_channel_norm = b_channel_axial / np.max(b_channel_axial) if np.max(b_channel_axial) > 0 else b_channel_axial
        ax_b_channel.imshow(np.rot90(b_channel_norm, k=3), cmap='Blues', origin='lower')
        ax_b_channel.axis('off')
        ax_b_channel.set_title('Blue Channel (S-I)', color='white', fontsize=12)
        
        # Add ROI overlays to blue channel
        for i, (roi, color) in enumerate(zip(rois, colors)):
            try:
                roi_data = roi.get_fdata()
                roi_slice = roi_data[:, :, z_slice]
                if np.any(roi_slice > 0):
                    roi_slice_rotated = np.rot90(roi_slice, k=3)
                    ax_b_channel.contour(roi_slice_rotated, colors=color, linewidths=1.5, alpha=0.9)
            except Exception as e:
                print(f"Error adding ROI {i+1} to blue channel: {e}")

        plt.tight_layout()

        from matplotlib.patches import Rectangle

        p_scr = Rectangle((0, 0), 1, 1, fc='red')
        p_slf = Rectangle((0, 0), 1, 1, fc='blue')

        plt.legend(
            [p_scr, p_slf],
            ['Projection', 'Association'],
            loc='lower right',
        )

        print(f"Saving {roi_name} page to PDF...")
        pdf.savefig(fig_color)
        print(f"{roi_name} page saved successfully")
        
        plt.close(fig_color)
        print(f"{roi_name} figure closed")


