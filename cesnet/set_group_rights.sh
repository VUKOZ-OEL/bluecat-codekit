#! bin/bash

chgrp -R intercost /storage/projects2/InterCOST
chmod g+s /storage/projects2/InterCOST


#!/bin/sh
#PBS -W umask=002
#PBS -W group_list=intercost