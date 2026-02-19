import os
import pandas as pd
import glob

#set input and output directories
subjects_dir = "/data/subjects_dti/OUTPUTS"
output_dir = "/data/OUTPUTS/ALPS_WMH_overlap"

#create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)

#concatenate the brain change csvs across subjects
concat_wm_alps_overlap = pd.concat([pd.read_csv(f) for f in glob.glob(f"{subjects_dir}/*/alps_output/alps_wmh_overlap.csv")], ignore_index=True)

#save the qc dataframe
concat_wm_alps_overlap.to_csv(f"{output_dir}/alps_wmh_overlap_full_report.csv", index=False)