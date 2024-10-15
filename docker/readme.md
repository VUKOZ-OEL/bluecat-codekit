r-lidar-tools - dockerfile creating image with tools to process lidar data in R [lidR, lasR]

to build image run: 	
```
docker build -t r-lidar-tools .
docker tag r-lidar-tools yourdockername/r-lidar-tools:latest
docker push yourdockername/r-lidar-tools:latest
```

to run on cesnet: ```singularity exec -B $SCRATCHDIR/:/data ./r-lidar-tools.img Rscript /data/rtest.R```

