.PHONY: all 

all:clean createtifs output/us-topo.json output/patch-topo.json output/world-topo.json output/world.png output/world-mobile.png output/world-es.png

clean:
	@rm -rf output/*
	@rm -rf satellite/intermediate/*
	@rm -rf satellite/resized-srtm/*

#CONFIGURE US MAP
output/us.json:input/cb_2016_us_state_20m.shp
	@ogr2ogr -f GeoJSON -t_srs crs:84 output/us.json input/cb_2016_us_state_20m.shp

output/us-topo.json:output/us.json
	@geo2topo states=output/us.json > output/us-topo.json


#CONFIGURE WORLD MAP
intermediate/world.json:globe-shps/TM_WORLD_BORDERS-0.3.shp
	@ogr2ogr -f GeoJSON -t_srs crs:84 intermediate/world.json globe-shps/TM_WORLD_BORDERS-0.3.shp

#pluck out countries we don't need
intermediate/world-simplified.json:intermediate/world.json
	@node simplify.js

#convert to topojson, then simplify
intermediate/world-topo-raw.json:intermediate/world-simplified.json
	@geo2topo countries=intermediate/world-simplified.json > intermediate/world-topo-raw.json

output/world-topo.json:intermediate/world-topo-raw.json
	@toposimplify -o output/world-topo.json -P 0.1 intermediate/world-topo-raw.json

#CONFIGURE PATCH MAP
output/patch-topo.json:input/gp/patch.json
	@geo2topo input/gp/patch.json > output/patch-topo.json

#create the png from the tiff
intermediate/bounds.shp:input/bounds.json
	@ogr2ogr -nlt POLYGON -skipfailures intermediate/bounds.shp input/bounds.json OGRGeoJSON

#for mobile
intermediate/bounds-mobile.shp:input/mobile-bound.json
	@ogr2ogr -nlt POLYGON -skipfailures intermediate/bounds-mobile.shp input/mobile-bound.json OGRGeoJSON

#resize tifs
createtifs:
	@gdalwarp -co 'tfw=yes' -ts 9000 ./satellite/srtm/srtm_*.tif ./satellite/resized-srtm/resized-merged.tif
	@magick convert ./satellite/srtm/srtm_*.tif -resize x300 ./satellite/resized-srtm/%d.tif

satellite/intermediate/world-warped.tif:./satellite/resized-srtm/resized-merged.tif
	@gdalwarp -co 'tfw=yes' -s_srs epsg:4326 -t_srs epsg:102003 ./satellite/resized-srtm/resized-merged.tif satellite/intermediate/world-warped.tif

satellite/intermediate/world-cropped.tif:intermediate/bounds.shp satellite/intermediate/world-warped.tif
	@gdalwarp -cutline intermediate/bounds.shp -crop_to_cutline -dstalpha satellite/intermediate/world-warped.tif satellite/intermediate/world-cropped.tif

#for mobile
satellite/intermediate/world-cropped-mobile.tif:intermediate/bounds-mobile.shp satellite/intermediate/world-warped.tif
	@gdalwarp -cutline intermediate/bounds-mobile.shp -crop_to_cutline -dstalpha satellite/intermediate/world-warped.tif satellite/intermediate/world-cropped-mobile.tif

satellite/intermediate/color-world.tif:satellite/intermediate/world-cropped.tif
	@rm -rf tmp && mkdir -p tmp
	@gdaldem hillshade $< tmp/hillshade.tmp.tif -z 5 -az 315 -alt 60 -compute_edges
	@gdal_calc.py -A tmp/hillshade.tmp.tif --outfile=$@ --calc="255*(A>220) + A*(A<=220)"
	@gdal_calc.py -A tmp/hillshade.tmp.tif --outfile=tmp/opacity_crop.tmp.tif --calc="1*(A>220) + (256-A)*(A<=220)"
	@rm -rf tmp

#for mobile
satellite/intermediate/color-world-mobile.tif:satellite/intermediate/world-cropped-mobile.tif
	@rm -rf tmp && mkdir -p tmp
	@gdaldem hillshade $< tmp/hillshade.tmp.tif -z 5 -az 315 -alt 60 -compute_edges
	@gdal_calc.py -A tmp/hillshade.tmp.tif --outfile=$@ --calc="255*(A>220) + A*(A<=220)"
	@gdal_calc.py -A tmp/hillshade.tmp.tif --outfile=tmp/opacity_crop.tmp.tif --calc="1*(A>220) + (256-A)*(A<=220)"
	@rm -rf tmp

intermediate/world-layer.png:satellite/intermediate/color-world.tif
	@magick convert satellite/intermediate/color-world.tif -resize x1620 intermediate/world-layer.png

intermediate/world-white.png:intermediate/world-layer.png input/labels.png
	@magick convert -page +0+0 intermediate/world-layer.png -page +0+0 input/labels.png -layers merge +repage intermediate/world-white.png
	
output/world.png:intermediate/world-white.png
	@magick convert intermediate/world-white.png -transparent white output/world.png

#for mobile
intermediate/world-mobile-layer.png:satellite/intermediate/color-world-mobile.tif
	@magick convert satellite/intermediate/color-world-mobile.tif -resize x760 intermediate/world-mobile-layer.png

output/world-mobile.png:intermediate/world-mobile-layer.png
	@magick convert intermediate/world-mobile-layer.png -transparent white output/world-mobile.png

#for es
intermediate/world-es-layer.png:satellite/intermediate/color-world.tif
	@magick convert satellite/intermediate/color-world.tif -resize x760 intermediate/world-es-layer.png

output/world-es.png:intermediate/world-es-layer.png
	@magick convert intermediate/world-es-layer.png -transparent white output/world-es.png
