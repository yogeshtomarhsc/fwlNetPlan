# fwlNetPlan
#
# This code has been tested on the following configuration
# Linux hscuser-OptiPlex-3046 4.15.0-115-generic #116-Ubuntu SMP Wed Aug 26 14:04:49 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux
# The packages Data::Dumper Geo::KML, Lib::XML and Math::Polygon have to be installed from metacpan.org
# The cpanm utility can be used
cpanm Data::Dumper Geo::KML Lib::XML Math::Polygon
# Installation
git clone https://github.com/abheeksaha/fwlNetPlan
# Installation consists of two scripts and four library modules
export PERL5LIB=.
# This ensures that the modules are picked up.
# The kmz.pl file processes individual kmz files and generates the output. The command format is
./kmz.pl -f <input kmz file> -k <output kmz/kml file> -r <report csv file> -w <whitelist file, csv format> -K <clustering method>
# Three clustering methods are supported.
-K Kmeans => Kmeans clustering (deprecated)
-K proximity<decimal num> => proximity clustering using <decimal num> as threshold. Most of our results use a value 3.5
-K <filename>, where <filename> is a file which is in the previously generated report format. 
This allows us to manually tweak the output of a previous run. The program expects the file to be in  the similar format
countyname,clustername,arbitrary comma separated values,(colon separated list of CBG Ids). New clusters can be added, 
old ones can be deleted or merged, etc.

# doall.pl is a worker script. It takes two options
-d <directory where the kmz files are stored>
-D <directory where the output files are to be reported>
-K common clustering rule
doall.pl calls kmz.pl with the clustering rule given for each file in the directory and stores the processed files with reports
in the output directory.
if -K is a directory, the doall script looks for filenames of the format <stateid>cluster.csv and loads that.

# We use the NLCD data files in the organization used by fetchSRTM. Unfortunately fetchSRTM only runs on Windows, so we
# had to download on windows and then move to a local Linux directory for performance. You can download the NLCD data for
the entire CONUS in one go, using the following parameters
North=51
West=-126
South=24
East=-66

# Set the environment variable NLCDHOME to point to where the NLCD data files are stored.
export NLCDHOME=<directory containing the top NLCD_2016 file>
