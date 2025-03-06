qsub -I -l select=1:ncpus=2:mem=12gb:scratch_local=20gb -l walltime=2:00:00

INPUT="/storage/plzen1/home/krucek/npo_sumava/sites/S4.laz"

install.packages("lidR",lib="/auto/plzen1/home/krucek/Rpackages", dependencies = T)
install.packages("terra",lib="/auto/plzen1/home/krucek/Rpackages", dependencies = T)
install.packages("RCSF",lib="/auto/plzen1/home/krucek/Rpackages")

export R_LIBS_USER="/auto/plzen1/home/krucek/Rpackages"

Sys.setenv(R_LIBS_USER = "/storage/plzen1/home/krucek/Rpackages")