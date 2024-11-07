# Program	    Function	        Description	                                                                                         Example Call
LAStools	las2col	            Converts LAS file to colorized format based on attributes	                                          las2col -i input.las -o output.las
LAStools	las2las	            Converts LAS files to different formats or versions	                                                las2las -i input.las -o output.las
LAStools	las2pg	            Exports LAS file data to PostgreSQL/PostGIS database	                                                las2pg -i input.las -o database.sql
LAStools	las2txt	            Converts LAS/LAZ files to text format for easier manipulation	                                      las2txt -i file.las -o output.txt
LAStools	lasblock	        Divides large LAS files into spatial blocks	                                                          lasblock -i input.las -o output_folder/
LAStools	lasinfo	            Displays detailed information about an LAS or LAZ file	                                              lasinfo file.las
LAStools	laszip-config	    Configures settings for laszip compression tool	                                                      laszip-config --set options
LAStools	laszippertest	    Tests laszip compression for integrity	                                                              laszippertest -i compressed.laz
LAStools	ts2las	            Converts ASCII-based Terrascan (.ts) files to LAS format	                                          ts2las -i input.ts -o output.las

RayCloudTools	rayalign	        Aligns two ray clouds or axis-aligns a single cloud to a major orthogonal plane	                      rayalign cloud1.ply cloud2.ply
RayCloudTools	raycolour	        Colors the end points of a ray cloud based on specified criteria (e.g., time, shape, normal)	      raycolour cloud.ply time --lit
RayCloudTools	raycombine	        Combines multiple ray clouds into one, with options for handling conflicts	                      raycombine base.ply min cloud1.ply
RayCloudTools	raycreate	        Generates a ray cloud from a specified model or description (e.g., forest, terrain)	              raycreate forest seed
RayCloudTools	raydecimate	    Reduces the density of a ray cloud to make it easier to process	                                  raydecimate cloud.ply 4 cm
RayCloudTools	raydenoise	        Removes rays with outlier endpoints to clean up noise	                                          raydenoise cloud.ply 2 sigmas
RayCloudTools	rayexport	        Converts a ray cloud back into a point cloud or trajectory file	                                  rayexport cloud.ply -o output.laz
RayCloudTools	rayextract	        Extracts specific real-world geometries, like terrain or forests, from a ray cloud	              rayextract cloud.ply terrain
RayCloudTools	rayimport	        Converts a point cloud and trajectory file into a ray cloud	                                      rayimport points.laz traj.txt
RayCloudTools	rayinfo	        Displays summary information about a ray cloud	                                                  rayinfo cloud.ply
RayCloudTools	rayrender	        Renders the ray cloud to an image, showing ray or point density	                                  rayrender cloud.ply
RayCloudTools	rayrestore	        Restores changes from a decimated ray cloud to the original high-density cloud	                  rayrestore decimated.ply original.ply
RayCloudTools	rayrotate	        Rotates the ray cloud by a specified angle along an axis	                                          rayrotate cloud.ply 0,0,90
RayCloudTools	raysmooth	        Adjusts ray endpoints to fit the nearest estimated surface	                                      raysmooth cloud.ply
RayCloudTools	raysplit	        Splits a ray cloud into two parts based on specified criteria (e.g., distance, direction)	      raysplit cloud.ply range 50
RayCloudTools	raytransients	    Separates a ray cloud into static and transient components, helping to remove moving objects	  raytransients cloud.ply
RayCloudTools	raytranslate	    Translates the ray cloud by a specified vector	                                                  raytranslate cloud.ply 1,2,3
RayCloudTools	raywrap	        Creates a mesh wrapping around the ray cloud, with options for different wrapping directions	  raywrap cloud.ply upwards 0.1
RayCloudTools	treecolour	    Colors trees within the ray cloud based on specified attributes	                                  treecolour cloud.ply intensity
RayCloudTools	treecombine	    Combines multiple tree cloud segments into one	                                                  treecombine tree1.ply tree2.ply
RayCloudTools	treecreate	    Generates synthetic tree ray clouds	                                                              treecreate seed
RayCloudTools	treedecimate	    Reduces tree cloud density to make it more manageable	                                          treedecimate tree.ply 2 cm
RayCloudTools	treediff	        Calculates the differences between two tree clouds for analysis	                                  treediff tree1.ply tree2.ply
RayCloudTools	treefoliage	    Identifies and extracts foliage sections from tree clouds	                                      treefoliage tree.ply
RayCloudTools	treegrow	        Simulates growth of tree clouds over a period of time	                                          treegrow tree.ply 5 years
RayCloudTools	treeinfo	        Displays summary information about a tree cloud	                                                  treeinfo tree.ply
RayCloudTools	treemesh	        Creates a mesh representation from a tree cloud	                                                  treemesh tree.ply
RayCloudTools	treepaint	        Paints tree clouds based on a specified criterion (e.g., seasonal change)	                      treepaint tree.ply spring
RayCloudTools	treeprune	        Removes specified branches or foliage from a tree cloud	                                      treeprune tree.ply
RayCloudTools	treerender	    Renders the tree cloud to an image for visualization	                                              treerender tree.ply
RayCloudTools	treerotate	    Rotates the tree cloud by a specified angle	                                                      treerotate tree.ply 0,0,45
RayCloudTools	treesmooth	    Smoothens the surface of a tree cloud	                                                              treesmooth tree.ply
RayCloudTools	treesplit	        Splits a tree cloud into two segments based on a criterion (e.g., height)	                      treesplit tree.ply height 5
RayCloudTools	treetranslate	    Translates the tree cloud by a specified vector	                                                  treetranslate tree.ply 1,2,3

