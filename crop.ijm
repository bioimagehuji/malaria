// This script uses apicoplast and nucleus fluorescence to crop Malaria infected RBCs from a large image.
// The last channel is assumed to be brightfield.

CROP_WIDTH = 150; // Width/height (in pixels) of each cell crop
MINIMUM_APICOPLAST_AREA = 7; // [microns] Smallest apicoplast size for each crop. Area, in microns, after 2D projection.

close("*");
print("\\Clear");

orig_filename = File.openDialog("Choose large image");
print(orig_filename);
dirname = File.getParent(orig_filename);
basename = File.getNameWithoutExtension(orig_filename);
dirCropOutput = dirname + File.separator + basename + "_crops";
print("dirCropOutput:", dirCropOutput);


run("Bio-Formats Importer", "open=[" + orig_filename + "] color_mode=Default rois_import=[ROI manager] " + 
	"view=Hyperstack stack_order=XYCZT use_virtual_stack");
rename("virtual");


// Open large image. 
Stack.getDimensions(im_width, im_height, channels, slices, frames);
// Only open first 1/2 channels which are fluorescent, and not the last channel, which is brightfield.
channels_to_open = channels - 1;

// For speed only open 1 in 3 z-slices and 1-in-3 time frames.
// Only open first 1/2 channels which are fluorescent, and not the last channel, which is brightfield.
// Open large image. 
run("Bio-Formats Importer", "open=[" + orig_filename + "] color_mode=Default rois_import=[ROI manager] " + 
	"specify_range view=Hyperstack stack_order=XYCZT c_begin=1 c_end=" + channels_to_open +	" c_step=1 " + 
	" z_begin=1 z_step=3 t_begin=1 t_step=3");
rename("orig");


// Do max intensity projection of Z,C,T to capture the location of the cells
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



run("Analyze Particles...", "size=" + MINIMUM_APICOPLAST_AREA + "-Infinity display exclude clear include add");

// Loop on ROIs and crop to files
File.makeDirectory(dirCropOutput);
selectWindow("thresh");
crop_number = 0;
    for (roi_id=0; roi_id<roiManager("count"); ++roi_id) {
        print("ROI+1:", roi_id+1);
        run("Enhance Contrast", "saturated=0.35");
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
		run("Bio-Formats Importer", "open=[" + orig_filename + "] color_mode=Default crop " +
			" rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT " + 
        	" x_coordinate_1=" + x +" width_1=" + CROP_WIDTH + 
        	" y_coordinate_1=" + y +" height_1=" + CROP_WIDTH );
        crop_number += 1;
        saveAs("Tiff", dirCropOutput+File.separator+"cell_3d_"+ crop_number + ".tif");
        close("cell_3d_"+ crop_number +".tif");
        selectWindow("thresh");
        run("Duplicate...", "title=crop_thumbnail");  // Does crop
        saveAs("Tiff", dirCropOutput+File.separator+"cell_"+ crop_number +".tif");
        close("cell_"+ crop_number +".tif");
        selectWindow("thresh");
    }
waitForUser("Done");