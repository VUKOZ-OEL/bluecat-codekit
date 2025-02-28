#!/bin/bash
#PBS -l select=1:ncpus=2:mem=16gb
#PBS -l walltime=01:00:00
#PBS -N lidR_job
#PBS -o output.log
#PBS -e error.log
#PBS -q default

INPUT="$1"

cp $INPUT $SCRATCHDIR/cloud.laz
cp /storage/plzen1/home/krucek/npo_sumava/dtm_csf.R $SCRATCHDIR/dtm_csf.R

cd $SCRATCHDIR

module add r/
Rscript dtm_csf.R

cp $SCRATCHDIR/ground_pts.laz "${INPUT%.laz}_csf_pts.laz"