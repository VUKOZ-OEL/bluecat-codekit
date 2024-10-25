# setup sublime: https://www.geeksforgeeks.org/how-to-use-terminal-in-sublime-text-editor/

# test_dir/master.sh
# move to scratch
cd $SCRATCHDIR
# get source code
module add git/ && echo "git loaded" >> $LOG_FILE || echo "git not loaded" >> $LOG_FILE
git clone https://github.com/VUKOZ-OEL/bluecat-codekit
cp bluecat-codekit/cesnet/rayprocess/*.sh $SCRATCHDIR

# set variables
export SOURCE_DATA=rudice_sample.laz
export DATADIR=/storage/plzen1/home/krucek/test_dir

export VOXELIZE=${3:-true}
export VOXEL_RES=${4:-0.05}
export ADD_TIME=${5:-true}


# process
#source $SCRATCHDIR/master_processor.sh 

