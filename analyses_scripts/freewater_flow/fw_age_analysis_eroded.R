library(ggplot2)
library(tidyverse)
library(readr)
library(dplyr)
library(glue)
library(nlme)
library(segmented)
library(effects)

out_dir <- "/Users/jasonkru/Documents/outputs/ABCDS/fw"
harmonized_data <- "/Users/jasonkru/Documents/outputs/ABCDS/fw/harmonized"
alps_dir <- "/Users/jasonkru/Documents/outputs/ABCDS/alps"

#load in the concatenated freewater data
fw_data <- read_csv(paste0(harmonized_data, "/fw_eroded_summary_harmonized.csv"))
alps_df <- read_csv(glue("{alps_dir}/harmonized/alps_summary_harmonized.csv"))

#make fsid column by pasting subject and event_sequence with _e in between
fw_data <- fw_data %>%
  mutate(fsid = paste(subject, event_sequence, sep = "_"))

#import overlap data
wmh_overlap <- read_csv(glue("{alps_dir}/alps_wmh_overlap_full_report.csv"))

#rename subject_id to fsid
colnames(wmh_overlap)[colnames(wmh_overlap) == "subject_id"] <- "fsid"

#filter wmh_overlap to only include rows where overlap > 0
wmh_overlap <- wmh_overlap %>%
  filter(voxel_overlap == 0)

#inner join alps_df and wmh_overlap by fsid to only keep participants with 0 overlap
alps_df <- inner_join(alps_df, wmh_overlap, by = "fsid")

#select fsid from alps_df
alps_df <- alps_df %>%
  dplyr::select(fsid, alps_harmonized)

#inner join alps_df and fw_data by fsid
fw_data <- inner_join(fw_data, alps_df, by = "fsid")

#remove scan_type_site.y column if it exists
if("scan_type_site.y" %in% colnames(fw_data)){
  fw_data <- fw_data %>%
    dplyr::select(-scan_type_site.y)
}

#rename scan_type_site.x to scan_type_site
if("scan_type_site.x" %in% colnames(fw_data)){
  fw_data <- fw_data %>%
    rename(scan_type_site = scan_type_site.x)
}

#remove the e from event_sequence to make it numeric
fw_data <- fw_data %>%
  mutate(event_sequence = as.numeric(str_remove(event_sequence, "e")))

#make fsid column by pasting subject and event_sequence with _e in between
fw_data <- fw_data %>%
  mutate(fsid = paste(subject, event_sequence, sep = "_e"))

#split scan_type_site into site by selecting chacters after last underscore
fw_data <- fw_data %>%
  mutate(site = str_extract(scan_type_site, "[^_]+$"))
#make site a factor
fw_data$site <- as.factor(fw_data$site)

#make group a factor
fw_data$group <- as.factor(fw_data$group)

#rename age_at_visit to age
fw_data <- fw_data %>%
  rename(age = age_at_visit)

#select where group ==1
fw_data_ds <- fw_data %>%
  filter(group == 1)

#model relationship between alps and cp-fw
alps_fw_model <- lme(
  fixed  = choroid_plexus_FW.combat ~ alps_harmonized + age + de_gender + site,
  random = ~ 1 | subject,
  data   = fw_data_ds,
  method = "REML"
)
summary(alps_fw_model)

csv_dir <- ("/Users/jasonkru/Documents/inputs/ABCDS/csvs")

#import the control_match csv
control_match_df <- read_csv(glue("{csv_dir}/control_match.csv"))


#rename subject_label to subject and event_sequence to event
colnames(control_match_df)[colnames(control_match_df) == "subject_label"] <- "subject"

#make new dataframe filtering bashed on subject_label in control_match_df
fw_ds_w_sib_df <- fw_data[fw_data$subject %in% control_match_df$sibptid1, ]
#select fsid, fw, subject_label, event from fw_ds_w_sib_df
fw_ds_w_sib_filt_df <- fw_ds_w_sib_df %>%
  dplyr::select(wm_FW.combat, choroid_plexus_FW.combat, subject, event_sequence, fsid)

#rename fw to fw_ds and fsid to fsid_ds
colnames(fw_ds_w_sib_filt_df)[colnames(fw_ds_w_sib_filt_df) == "fw"] <- "fw_ds"
colnames(fw_ds_w_sib_filt_df)[colnames(fw_ds_w_sib_filt_df) == "fsid"] <- "fsid_ds"

fw_control_df <- fw_data[fw_data$subject %in% control_match_df$subject, ]
#select fsid, fw, subject_label, event from fw_control_df
fw_control_filt_df <- fw_control_df %>%
    dplyr::select(wm_FW.combat, choroid_plexus_FW.combat, subject, event_sequence, fsid)

#rename fw to fw_control and fsid to fsid_control
colnames(fw_control_filt_df)[colnames(fw_control_filt_df) == "fsid"] <- "fsid_control"
colnames(fw_control_filt_df)[colnames(fw_control_filt_df) == "fw"] <- "fw_control"

#from control_match_df, select sibptid1 and and subject_label
control_match_df <- control_match_df %>%
  dplyr::select(sibptid1, subject, event_sequence)

#make event character
control_match_df$event <- as.character(control_match_df$event_sequence)
fw_ds_w_sib_filt_df$event <- as.character(fw_ds_w_sib_filt_df$event_sequence)
fw_control_filt_df$event <- as.character(fw_control_filt_df$event_sequence)

#merge fw_control_filt_df and control_match_df on subject_label
fw_control_filt_df <- inner_join(fw_control_filt_df, control_match_df, by = c("subject", "event_sequence"))

#add a family column to fw_control_filt_df based on each unique subject label starting at 1
fw_control_filt_df <- fw_control_filt_df %>%
  mutate(family = as.numeric(as.factor(subject)))

#select fsid and family
ds_fam_df <- fw_control_filt_df %>%
  dplyr::select(sibptid1, event_sequence, family)

#select fsid and family
control_fam_df <- fw_control_filt_df %>%
  dplyr::select(subject, event_sequence, family)

#rename sibptid1 to subject
colnames(ds_fam_df)[colnames(ds_fam_df) == "sibptid1"] <- "subject"


#stack ds_fam_df and control_fam_df
fam_df <- rbind(ds_fam_df, control_fam_df)

#stack fw_ds_w_sib_df and fam_df
fw_ds_w_sib_df <- rbind(fw_ds_w_sib_df, fw_control_df)

#inner join fw_ds_w_sib_df and fam_df on subject and event
fw_ds_w_sib_df <- inner_join(fw_ds_w_sib_df, fam_df, by = c("subject", "event_sequence"))

long_sib_df <- fw_ds_w_sib_df

# Convert to wide format
paired_data <- fw_ds_w_sib_df %>%
  pivot_wider(
    names_from = group, 
    values_from = c(wm_FW.combat, choroid_plexus_FW.combat), 
    id_cols = c(family, event_sequence),
    names_prefix = "group_"
  ) 

#remove any rows with NA
paired_data <- paired_data %>%
  drop_na()

#select min event for each family
paired_data <- paired_data %>%
  group_by(family) %>%
  filter(event_sequence == min(event_sequence)) %>%
  ungroup()


#Make group factor with labels DS and SC
long_sib_df$group <- factor(long_sib_df$group, levels = c(1, 2), labels = c("DS", "SC"))

# Mean with confidence intervals plot
ggplot(long_sib_df, aes(x = group, y = choroid_plexus_FW.combat, color = group)) +
  stat_summary(fun = mean, geom = "point", size = 5) +
  stat_summary(fun.data = mean_cl_normal, geom = "errorbar", width = 0.4) +
  geom_line(data = long_sib_df, aes(x = group, y = choroid_plexus_FW.combat, group = family), size=0.2, alpha = 0.3, inherit.aes = FALSE) +
  geom_point(data = long_sib_df, aes(x = group, y = choroid_plexus_FW.combat, color = group), size = 0.5) +
  labs(x = "Group", y = "CP-FWf") +
  theme_minimal() +
    theme_minimal(base_size = 36) +
    theme(
        panel.grid = element_blank(),
        axis.line = element_line(color = "black"),
    axis.ticks.x = element_line(color = "black"),
    axis.ticks.length = grid::unit(4, "pt"),
        axis.title = element_text(face = "bold"),
        panel.background = element_rect(fill = "white", color = NA),
        plot.background = element_rect(fill = "white", color = NA),
        legend.position = "none"
    )

ggsave(glue("{out_dir}/cp_fw_paired_t_test_plot.svg"), width = 10, height = 8)

#select only baseline event_sequence (based on min event_sequence for each family)
bl_sib_df <- long_sib_df %>%
  group_by(family) %>%
  filter(event_sequence == min(event_sequence)) %>%
  ungroup()

#remove families with only one entry
remove_unique_family <- function(df, family_col = "family") {
  df %>%
    group_by(.data[[family_col]]) %>%
    filter(n() > 1) %>%
    ungroup()
}

#drop families with only one entry
bl_sib_df <- remove_unique_family(bl_sib_df)

cp_mod_bl <- lme(
  fixed  = choroid_plexus_FW.combat ~ group + age + de_gender + site,
  random = ~ 1 | family,
  data   = bl_sib_df,
  method = "REML"
)
summary(cp_mod_bl)
intervals(cp_mod_bl, which = "fixed")

# From long_sib_df, select fsid, family
family_group <- long_sib_df %>%
  dplyr::select(fsid, family)

#left join family_group to fw_data on fsid
fw_data <- left_join(fw_data, family_group, by = "fsid")

#fill in NA family values with unique numbers starting after the max family number
max_family <- max(fw_data$family, na.rm = TRUE)

# Create a mapping of subjects with NAs to new unique family IDs
na_subject_mapping <- fw_data %>%
  filter(is.na(family)) %>%
  distinct(subject) %>%
  mutate(new_family_id = row_number() + max_family)

# Apply the mapping to fill NAs
fw_data <- fw_data %>%
  left_join(na_subject_mapping, by = "subject") %>%
  mutate(family = ifelse(is.na(family), new_family_id, family)) %>%
  dplyr::select(-new_family_id)

#make family a factor
fw_data$family <- as.factor(fw_data$family)

#plot longitudinal data


#compare longitudinal change in fw by group with interaction of group and age_at_visit
long_comparison <- lme(choroid_plexus_FW.combat ~ group + age + de_gender + site, data = fw_data, random = ~1|family/subject, method = "REML")
summary(long_comparison)
intervals(long_comparison, which = "fixed")

long_comp_interaction <- lme(choroid_plexus_FW.combat ~ group * age + de_gender + site, data = fw_data, random = ~1|family/subject, method = "REML")
summary(long_comp_interaction)
intervals(long_comp_interaction, which = "fixed")

#get min_visit_number for each subject
fw_data <- fw_data %>%
  group_by(subject) %>%
   mutate(min_visit_number = min(event_sequence)) %>%
  ungroup()

# Make baseline_df with family
baseline_df_fam <- fw_data %>%
  filter(event_sequence == min_visit_number)

# Linear model for baseline comparison with family as random effect
bl_comparison_fam <- lme(choroid_plexus_FW.combat ~ group + age + de_gender + site, random = ~1|family, data = baseline_df_fam, method = "REML")
summary(bl_comparison_fam)
intervals(bl_comparison_fam, which = "fixed")

effects_df <- as.data.frame(Effect(c("age", "group"), long_comparison, xlevels = list(age = seq(min(fw_data$age), max(fw_data$age), length.out = 100))))

#plot linear model of fw by age separated by group
ggplot(fw_data, aes(x = age, y = choroid_plexus_FW.combat, color = group)) +
  geom_point(data = fw_data, aes(x = age, y = choroid_plexus_FW.combat), alpha = 0.5, size = 0.5) +
  labs(x = "Age at Visit", y = "CP-FWf") +
  theme_minimal(base_size = 36) +
  geom_line(data = fw_data, aes(x = age, y = choroid_plexus_FW.combat, group = subject, color = group), size = 0.4, alpha = 0.3, inherit.aes = FALSE) +
  geom_ribbon(data = effects_df, 
              aes(x = age, ymin = lower, ymax = upper, fill = group), 
              alpha = 0.2, inherit.aes = FALSE) +
  geom_line(data = effects_df, 
            aes(x = age, y = fit, color = group), 
            size = 1.5) +

  scale_color_discrete(labels = c("1" = "DS", "2" = "SC")) +
  scale_fill_discrete(labels = c("1" = "DS", "2" = "SC")) +
  theme(
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    legend.text = element_text(size = 20, face = "bold"),
    legend.title = element_blank(),
    legend.key.height = unit(1.5, "cm"),
    legend.margin = margin(0, 0, 0, 0),
    legend.box.margin = margin(0, 0, 0, 0)
  )

ggsave(glue("{out_dir}/choroid_plexus_FW_longitudinal_comparison_plot.svg"), width = 10, height = 8)

# Add min_visit_number column for each subject
fw_data <- fw_data %>%
  group_by(subject) %>%
  mutate(min_visit_number = min(event_sequence)) %>%
  ungroup()

# Now filter for baseline
baseline_df <- fw_data %>%
  filter(event_sequence == min_visit_number)

#violin plot of cpfw by group
ggplot(baseline_df, aes(x = group, y = choroid_plexus_FW.combat, color = group)) +
  geom_point(data = baseline_df, aes(x = group, y = choroid_plexus_FW.combat, color = group), position = position_jitter(width = 0.2), size = 0.5) +
  stat_summary(fun = mean, geom = "point", size = 5, color = "black") +
  stat_summary(fun.data = mean_cl_normal, geom = "errorbar", width = 0.4, color = "black") +
  labs(x = "Group", y = "CP-FWf") +
  scale_x_discrete(labels = c("1" = "DS", "2" = "SC")) +
  theme_minimal() +
  theme_minimal(base_size = 36) +
  theme(
    axis.title.y = element_markdown(),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    axis.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    legend.position = "none"
  )

ggsave(glue("{out_dir}/cpfw_baseline_comparison_plot.svg"), width = 10, height = 8)



#test effect of sex on alps in ds_baseline
t_test_sex_fw <- t.test(choroid_plexus_FW.combat ~ de_gender, data = fw_data_ds)
print(t_test_sex_fw)
lme_sex_fw <- lme(choroid_plexus_FW.combat ~ de_gender + age + site, random = ~1|subject, data = fw_data_ds, method = "REML")
summary(lme_sex_fw)
intervals(lme_sex_fw, which = "fixed")
