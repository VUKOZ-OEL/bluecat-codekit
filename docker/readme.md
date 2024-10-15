r-lidar-tools - dockerfile creating image with tools to process lidar data in R [lidR, lasR]

to build image run: 	
```
docker build -t r-lidar-tools .
docker tag r-lidar-tools yourdockername/r-lidar-tools:latest
docker push yourdockername/r-lidar-tools:latest
```