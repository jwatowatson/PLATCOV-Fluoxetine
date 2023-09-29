## Load randomisation data to get ITT database
library(dplyr)
ff_names = list.files(path = "~/Dropbox/PLATCOV", pattern = 'data',full.names = T)
flx_sites = c('TH1', 'BR3', 'PK01', 'LA08')

data_list = list()
for(i in 1:length(ff_names)){
  data_list[[i]] = read.csv(ff_names[i])
  data_list[[i]]$Date = as.POSIXct(data_list[[i]]$Date,format='%a %b %d %H:%M:%S %Y')
  my_prefix=gsub(x = strsplit(ff_names[i], split = 'data-')[[1]][2], pattern = '.csv',replacement = '')
  print(my_prefix)
  
  data_list[[i]]$ID = paste('PLT-', my_prefix, '-', data_list[[i]]$randomizationID, sep='')
  data_list[[i]] = data_list[[i]][, c('ID', 'Treatment', 'Date','site')]
}

xx = bind_rows(data_list)

library(stringr)
for(i in 1:nrow(xx)){
  id = unlist(strsplit(xx$ID[i],split = '-'))
  id[3] = str_pad(id[3], 3, pad = "0")
  id = paste(id, collapse = '-')
  xx$ID[i]=id
}

itt_flx = 
  xx %>% filter( (site=='TH1' & Date >= "2022-04-01 00:00:00") |
                   (site=='BR3' & Date >= "2022-06-21 00:00:00") |
                   (site=='LA08' & Date >= "2022-06-21 00:00:00") |
                   (site=='PK01' & Date >= "2022-06-21 00:00:00"),
                 Date < "2023-05-09 00:00:00") %>%
  arrange(site, Date, ID)

table(itt_flx$Treatment)
table(itt_flx$Treatment, itt_flx$site)

itt_flx$ID = gsub(pattern = 'PK01',replacement = 'PK1',x = itt_flx$ID)
itt_flx$ID = gsub(pattern = 'LA08',replacement = 'LA8',x = itt_flx$ID)

write.csv(x = itt_flx, file = 'ITT_population.csv')

