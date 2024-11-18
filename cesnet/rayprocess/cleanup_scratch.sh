# remove 
rm -rf bluecat-codekit
rm -rf $SOURCE_DATA
rm -rf cloud.laz
rm -rf raycloudtools.img
rm -rf pdal.img

rm -rf segments/cloud_segmented.laz
rm -rf segments/cloud_segmented.ply
rm -rf segments/cloud_segmented.txt

rm -rf segments/*.txt

mkdir -p segments/ply && mv segments/*.ply segments/ply/
mkdir -p segments/laz && mv segments/*.laz segments/laz/
mkdir -p segments/png && mv segments/*.png segments/png/

mkdir -p log && mv *.sh log/
mv pdal_pipeline.json log/
mv system_usage.log log/ 

