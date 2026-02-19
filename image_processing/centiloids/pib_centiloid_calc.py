import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import scipy.stats as stats
import seaborn as sns
from sklearn.metrics import r2_score
import os
import shutil
import sys

OUTCSV = f'/data/OUTPUT/pib_centiloids_f5.csv'
in_dir = '/data/centiloid/subjects'
proc_dir = '/data/centiloid/subjects/PROC_pib'

os.makedirs('/data/OUTPUT', exist_ok=True)

suvr_df = pd.DataFrame(columns=['ID', 'SUVR'])

# Check if proc_dir exists
if not os.path.exists(proc_dir):
    print(f"Error: Processing directory {proc_dir} does not exist")
    sys.exit(1)

# Make sure there are processed subjects
if len(os.listdir(proc_dir)) == 0:
    print(f"Error: No processed subjects found in {proc_dir}")
    sys.exit(1)

# Combine all suvr csvs into one df
print(f"Looking for subject data in {proc_dir}")
for subject in os.listdir(proc_dir):
    subject_csv = f'{proc_dir}/{subject}/{subject}_pib_standard_centiloid_suvr.csv'
    print(f"Checking for subject data at: {subject_csv}")
    
    if os.path.exists(subject_csv):
        try:
            subject_df = pd.read_csv(subject_csv)
            suvr_df = pd.concat([suvr_df, subject_df])
            print(f"Added SUVR data for {subject}")
        except Exception as e:
            print(f"Error reading CSV for {subject}: {e}")
    else:
        print(f"Warning: SUVR CSV not found for {subject}: {subject_csv}")

# Check data was loaded
if len(suvr_df) == 0:
    print("Error: No SUVR data was loaded. Check that CSV files exist in the correct locations.")
    sys.exit(1)

print(f"Loaded SUVR data for {len(suvr_df)} subjects")

# Import CSV
validation_df = pd.read_csv('/data/scripts/gaain_validation.csv')

#Split df to young and AD
pib_hc_df = validation_df[validation_df['ID'].str.contains('YC')].copy()
pib_AD_df = validation_df[validation_df['ID'].str.contains('AD')].copy()

# Average SUVR for HC
hc_mean_suvr = pib_hc_df["SUVR"].mean()

# Average SUVR for AD
AD_mean_suvr = pib_AD_df["SUVR"].mean()

#AD - HC
ad_hc_dif = AD_mean_suvr - hc_mean_suvr

#Establish centiloid equation CL = 100(PiBSUVRind - PiBSUVRYC)/(PiBSUVRAD100 - PiBSUVRYC)
print(f"Healthy control mean SUVr: {hc_mean_suvr} \nAD mean SUVr: {AD_mean_suvr} \nKlunk equation: CL = 100(SUVr - {hc_mean_suvr})/({ad_hc_dif})")

#calc centiloids from our equation
suvr_df["Centiloids"] = 100 * (suvr_df['SUVR'] - hc_mean_suvr) / ad_hc_dif

#direct calc of pib_centiloids
suvr_df["Direct Centiloids"] = 100*(suvr_df["SUVR"] - 1.009)/(1.067)

#sort by ID
suvr_df = suvr_df.sort_values(by='ID')

#write to csv
suvr_df.to_csv(OUTCSV, index=False)

#combine individual subjects pdfs into one pdf
pdf_dir = '/data/OUTPUT/PDFs'
os.makedirs(pdf_dir, exist_ok=True)

for subject in os.listdir(proc_dir):
    pdf_path = f'{pdf_dir}/{subject}_report.pdf'
    shutil.copy(f'{proc_dir}/{subject}/{subject}_report.pdf', pdf_path)
