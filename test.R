# script for running all the stan models with all settings on the BMRC cluster
args = commandArgs(trailingOnly = FALSE) # comes from the SGE_TASKID in *.sh file
#print(args)
job_i = as.numeric(args[6])
print(paste0("job(i) = ", job_i)) # this will print out in the *.o file