# script for running all the stan models with all settings on the BMRC cluster
args = commandArgs(trailingOnly = FALSE) # comes from the SGE_TASKID in *.sh file
job_i = as.numeric(args[6])
print(paste0("job(i) = ", job_i)) # this will print out in the *.o file

## Packages needed
library(rstan)
library(matrixStats)
library(doParallel)
library(dplyr)

source('functions.R')
source('priors.R')

load('Rout/model_settings_Fluoxitine_new.RData')

Max_job = nrow(model_settings)
if(job_i > Max_job) stop('no model setting corresponding to job ID')

writeLines('Doing the following job:')
print(model_settings[job_i, ])

platcov_dat <- data_list[[model_settings$Data_ID[job_i]]]
Dmax <- model_settings$Dmax[job_i]

# Analysis data
platcov_dat_analysis = 
  platcov_dat %>% ungroup() %>%
  filter(Time <= Dmax, mITT) %>%
  arrange(log10_viral_load==log10_cens_vl) %>%
  mutate(Variant = as.factor(Variant),
         Site = as.factor(Site),
         RnaseP_scaled = scale(40 - CT_RNaseP,scale = F),
         Mean_age = mean(Age[!duplicated(ID)]),
         SD_age = sd(Age[!duplicated(ID)]),
         Age_scaled = (Age-Mean_age)/SD_age,
         Symptom_onset = ifelse(is.na(Symptom_onset),2,Symptom_onset)) 

covs_base = c('Study_time','Site')
covs_full=c(covs_base, 'Age_scaled','Symptom_onset','N_dose')
stan_input_job = 
  make_stan_inputs(input_data_fit = platcov_dat_analysis,
                   int_covs_base = covs_base,
                   int_covs_full = covs_full,
                   slope_covs_base = covs_base,
                   slope_covs_full = covs_full,
                   trt_frmla = formula('~ Trt'),
                   Dmax = Dmax)



options(mc.cores = model_settings$Nchain[job_i])
stopifnot(model_settings$Nchain[job_i]>getDoParWorkers()) # check worker number assigned

mod = stan_model(file = as.character(model_settings$mod[job_i])) # compile 

#stan_input_job = stan_inputs[[model_settings$dataset[job_i]]]

analysis_data_stan = stan_input_job$analysis_data_stan
analysis_data_stan$trt_mat = stan_input_job$Trt_matrix
analysis_data_stan$K_trt = ncol(analysis_data_stan$trt_mat)

x_intercept = stan_input_job$cov_matrices$X_int[[model_settings$cov_matrices[job_i]]]
if(ncol(x_intercept)==0) x_intercept = array(0, dim=c(nrow(x_intercept),1))
analysis_data_stan$x_intercept = x_intercept
analysis_data_stan$K_cov_intercept= ncol(x_intercept)


x_slope = stan_input_job$cov_matrices$X_slope[[model_settings$cov_matrices[job_i]]]
if(ncol(x_slope)==0) x_slope = array(0, dim=c(nrow(x_slope),1))
analysis_data_stan$x_slope = x_slope
analysis_data_stan$K_cov_slope=ncol(x_slope)


# sample posterior
out = sampling(mod, 
               data=c(analysis_data_stan,
                      all_priors[[model_settings$prior[job_i]]]),
               iter=model_settings$Niter[job_i],
               chain=model_settings$Nchain[job_i],
               thin=model_settings$Nthin[job_i],
               warmup=model_settings$Nwarmup[job_i],
               save_warmup = FALSE,
               seed=job_i,
               pars=c('L_Omega'), # we don't save this as it takes up lots of memory!
               include=FALSE)


save(out, file = paste0('Rout/model_fits_',job_i,'.RData'))# save output

writeLines('Finished job')

