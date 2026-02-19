# -*- coding: utf-8 -*-
"""
Created on Mon Dec  4 15:02:36 2023

@author: russj13
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import scipy.stats as stats
import seaborn as sns
from sklearn.metrics import r2_score
import os
import shutil
import sys
OUTCSV = f'/data/OUTPUT/fbp_centiloids_f5.csv'
in_dir = '/data/centiloid/subjects'
proc_dir_fbp = '/data/centiloid/subjects/PROC_fbp'

os.makedirs('/data/OUTPUT', exist_ok=True)

# Check if proc_dir exists
if not os.path.exists(proc_dir_fbp):
    print(f"Error: Processing directory {proc_dir_fbp} does not exist")
    sys.exit(1)


# Make sure there are processed subjects
if len(os.listdir(proc_dir_fbp)) == 0:
    print(f"Error: No processed subjects found in {proc_dir_fbp}")
    sys.exit(1)



fbp_df = pd.DataFrame()

# Combine all suvr csvs into one df
print(f"Looking for subject data in {proc_dir_fbp}")
for subject in os.listdir(proc_dir_fbp):
    subject_csv = f'{proc_dir_fbp}/{subject}/{subject}_fbp_standard_centiloid_suvr.csv'
    print(f"Checking for subject data at: {subject_csv}")
    
    if os.path.exists(subject_csv):
        try:
            subject_df = pd.read_csv(subject_csv)
            fbp_df = pd.concat([fbp_df, subject_df])

            print(f"Added SUVR data for {subject}")
        except Exception as e:
            print(f"Error reading CSV for {subject}: {e}")
    else:
        print(f"Warning: SUVR CSV not found for {subject}: {subject_csv}")

# Check data
# Combine all pib suvr csvs into one df
if len(fbp_df) == 0:
    print("Error: No SUVR data was loaded. Check that CSV files exist in the correct locations.")
    sys.exit(1)

print(f"Loaded SUVR data for {len(fbp_df)} subjects")

#sort by ID
fbp_df = fbp_df.sort_values(by='ID')

#rename SUVR to fbp_suvr
fbp_df = fbp_df.rename(columns={'SUVR': 'fbp_suvr'})

# Check if we have data to proceed
if len(fbp_df) == 0:
    print("Error: No SUVR data was loaded. Check that CSV files exist in the correct locations.")
    sys.exit(1)


# Import validation CSV
validation_df = pd.read_csv('/data/scripts/gaain_validation.csv')
fbp_validation_df = pd.read_csv('/data/scripts/fbp_centiloids.csv')


#Split df to young and AD
pib_hc_df = validation_df[validation_df['ID'].str.contains('YC')].copy()
pib_AD_df = validation_df[validation_df['ID'].str.contains('AD')].copy()

# Average SUVR for HC
hc_mean_suvr = pib_hc_df["SUVR"].mean()

# Average SUVR for AD
AD_mean_suvr = pib_AD_df["SUVR"].mean()

#AD - HC:
ad_hc_dif = AD_mean_suvr - hc_mean_suvr

#Establish centiloid equation CL = 100(PiBSUVRind - PiBSUVRYC)/(PiBSUVRAD100 - PiBSUVRYC)
print(f"Healthy control mean SUVr: {hc_mean_suvr} \nAD mean SUVr: {AD_mean_suvr} \nKlunk equation: CL = 100(SUVr - {hc_mean_suvr})/({ad_hc_dif})")


CLs=[]

#Calculate individual CL values
for index, row in validation_df.iterrows():
    cl = 100 * (row['SUVR'] - hc_mean_suvr) / ad_hc_dif
    CLs.append(cl)
    
validation_df["Calculated CLs"]=CLs

# Plot fbp vs PiB suvr and calculate equation of line
slope_fbp, intercept_fbp, r_value_fbp, p_value_fbp, std_err_fbp = stats.linregress(fbp_validation_df['fbp_suvr'],fbp_validation_df['pib_suvr'])


#calculated PiB SUVRs from FBP

fbp_df["Calculated PiB SUVR"] = slope_fbp * fbp_df["fbp_suvr"] + intercept_fbp

#calculate centiloid from pib calc

fbp_df["Centiloids"] = 100*(fbp_df["Calculated PiB SUVR"] - hc_mean_suvr)/(ad_hc_dif)

#Direct calc of fbp_centiloids
fbp_df["Direct Centiloids"] = 175*fbp_df["fbp_suvr"] - 182

#sort by ID
fbp_df = fbp_df.sort_values(by='ID')

fbp_df.to_csv(OUTCSV, index=False)

fbp_pdf_dir = '/data/OUTPUT/Fbp_PDFs'
os.makedirs(fbp_pdf_dir, exist_ok=True)

for subject in os.listdir(proc_dir_fbp):
    pdf_path = f'{fbp_pdf_dir}/{subject}_report.pdf'
    shutil.copy(f'{proc_dir_fbp}/{subject}/{subject}_report.pdf', pdf_path)