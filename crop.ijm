// This script uses apicoplast and nucleus fluorescence to crop Malaria infected RBCs from a large image.
// The last channel is assumed to be brightfield.

// User parameters
CROP_WIDTH = 150; // Width/height (in pixels) of each cell crop
MINIMUM_APICOPLAST_AREA = 7; // [microns] Smallest apicoplast size for each crop. Area, in microns, after 2D projection.

// Initialize
close("*");
print("\\Clear");
run("Bio-Formats Macro Extensions"); // required for Ext.getSeriesCount


// Ask for image from user
debug_image = call("java.lang.System.getenv", "MALARIA_IMAGE");
if (debug_image==0) {  // if MALARIA_IMAGE environment variable not defined
	orig_filename = File.openDialog("Choose large image");
} 
else {
	orig_filename = debug_image;
}
print("orig_filename:", orig_filename);
dirname = File.getParent(orig_filename);
basename = File.getNameWithoutExtension(orig_filename);
dirCropOutput = dirname + File.separator + basename + "_crops";
print("dirCropOutput:", dirCropOutput);

// Read from large image the number of series/channels without opening the image
print("intitializeing file:", orig_filename);
Ext.setId(orig_filename);
Ext.getSeriesCount(seriesCount)
print("seriesCount:", seriesCount);
Ext.getSizeC(channels);
print("channels:", channels);
Ext.close();

// Each series is a field from the microscope with several cells to crop
for (series=1; series<=seriesCount; ++series) {
	// Only open first one or two channels which are fluorescent, and not the last channel, which is brightfield.
	channels_to_open = channels - 1;
	print("channels_to_open:", channels_to_open);

	// Open each series from the large image. 
	// For speed, open only 1 in 3 z-slices and 1-in-3 time frames.
	// Also, open only the first one or two channels (which are fluorescent, and not the last channel, which is brightfield.)
	run("Bio-Formats Importer", "open=[" + orig_filename + "] color_mode=Default rois_import=[ROI manager] " + 
		"specify_range view=Hyperstack stack_order=XYCZT series_"+series +
		" c_begin_"+series+"=1 c_end_"+series+"=" + channels_to_open +	" c_step_1=1 " + 
		"  z_step_"+series+"=3 " +
		"  t_step_"+series+"=3 ");
	rename("orig_series");

	// Do max intensity projection of Z,C,T to capture the location of the cells/crops
	// Projection Z
	run("Z Project...", "projection=[Max Intensity] all");
	rename("MIP_z");
	
	// Projection time
	run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	run("Z Project...", "projection=[Max Intensity]");
	rename("MIP_time");
	run("Duplicate...", "title=thresh_channels duplicate");

	run("Smooth"); // To connect apicoplasts in cell before thresholding
	resetMinAndMax();
	run("Enhance Contrast", "saturated=0.35");
	run("Apply LUT");
	if (channels_to_open > 1) {
		run("Convert to Mask", "method=Otsu background=Dark calculate black");
	}
	else {
		setAutoThreshold("Otsu dark no-reset");
		run("Convert to Mask");
	}

	// Projection Channels
	if (channels_to_open == 2) {
		run("Z Project...", "projection=[Max Intensity]");  // Merge 2 color channels to one channel
	}
	rename("thresh");
	run("Enhance Contrast", "saturated=0.35");
	run("Analyze Particles...", "size=" + MINIMUM_APICOPLAST_AREA + "-Infinity display exclude clear include add");
	

	// Loop on ROIs and crop to files
	File.makeDirectory(dirCropOutput);
	File.makeDirectory(dirCropOutput+ "/thumbnails");
	selectWindow("thresh");
	crop_number = 0;
    for (roi_id=0; roi_id<roiManager("count"); ++roi_id) {
        print("ROI+1:", roi_id+1);
        roiManager("Select", roi_id);
        run("To Bounding Box");
        Roi.getBounds(x, y, width, height);
		//        print("xs" , x, x + width);
      	xcenter = x + floor(width/2);
      	x = xcenter - floor(CROP_WIDTH/2);
		//    	print("new xs" , x, x+CROP_WIDTH);
    	if ((x < 0) || (x+CROP_WIDTH > getWidth())) {
    		print("Skipping ROI, out of image bounds:", x, x+CROP_WIDTH);
    		continue;
    	}
        print("y" , y, y+height);
        ycenter = y+floor(height/2);
        y = ycenter - floor(CROP_WIDTH / 2);
    	print("new ys" , y, y+CROP_WIDTH);
    	if ((y < 0) || (y+CROP_WIDTH > getHeight())) {
    		print("Skipping ROI, out of image bounds:", y, y+CROP_WIDTH);
    		continue;
    	}
		makeRectangle(x, y, CROP_WIDTH, CROP_WIDTH);
		print("Reading crop from large image...");

		// Load crop
		run("Bio-Formats Importer", "open=[" + orig_filename + "] color_mode=Default crop " +
			" rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT " + 
        	" x_coordinate_1=" + x +" width_1=" + CROP_WIDTH + 
        	" y_coordinate_1=" + y +" height_1=" + CROP_WIDTH );
        print("done reading");
        crop_number += 1;
        crop_name = "crop_S" + series +"_CROPNUM" + crop_number + ".tif";
        saveAs("Tiff", dirCropOutput+File.separator+crop_name);

        // Create a 2D thumbnail image of crop projected in Z an T with threshold
        selectWindow("thresh");
        run("Duplicate...", "title=crop_thumbnail"); // crop the thumbnail 2D image
		thumbnail_name = "thumbnail_"+ crop_name;
        saveAs("Tiff", dirCropOutput+ "/thumbnails/" + thumbnail_name);

		close(crop_name);
        close(thumbnail_name);
		print("Finished crop " + crop_name);
    } // for crop
    close("thresh");
    close("thresh_channels");
    close("MIP_time");
    close("MIP_z");
    close("orig_series");
    print("Finished series " + series);
} // series
print("Finished large image");
waitForUser("Done");