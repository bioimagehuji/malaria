// This script creates crops Malaria apicoplast and nucleus from fluorescence images.
// Input: 
//     A directory with subdirectories: 24h, 48h. In each sub-directory, there are image files. 
//     Each image contains multiple series (fields), and 3 channels: apicoplast cluorescence channel, nucleus fluorescence channel, and brightfield.
// Output: 
//     Image crops in a directory whose name ends with "_crops". The directory has a similar structure to the input directory.
//     Each input image get a new directory that ends with "_crops" and contains the cropped images.
//     There is also a sub-directory with MIP projections of the crops.
// Use the analyze_crops.ijm script after running this script.

// User parameters
CROP_WIDTH = 150; // Width/height (in pixels) of each cell crop
MINIMUM_APICOPLAST_AREA = 7; // [microns] Smallest apicoplast size for each crop. Area, in microns, after 2D projection.
INTENSITY_THRESHOLD = 500;


// Initialize
close("*");
print("\\Clear");
run("Bio-Formats Macro Extensions"); // required for Ext.getSeriesCount

DEBUG = false;
print("DEBUG: " + DEBUG);
// Envionment variables set e.g. by the shell script
MALARIA_SHELL_SCRIPT = call("java.lang.System.getenv", "MALARIA_SHELL_SCRIPT");
print("MALARIA_SHELL_SCRIPT: " + MALARIA_SHELL_SCRIPT);
MALARIA_MAX_CROPS = call("java.lang.System.getenv", "MALARIA_MAX_CROPS");
print("MALARIA_MAX_CROPS: " + MALARIA_MAX_CROPS);
MALARIA_DIRECTORY = call("java.lang.System.getenv", "MALARIA_DIRECTORY");
print("MALARIA_DIRECTORY: " + MALARIA_DIRECTORY);


// Crop all infeted cells
function process_image(image_file, crops_dir_output) {
	print("Processing image: " + image_file);
	
	// Read from large image the number of series without opening the image
	print("intitializeing file:", image_file);
	Ext.setId(image_file);
	Ext.getSeriesCount(seriesCount)
	if (DEBUG) {
		seriesCount = 2;
	}
	print("seriesCount:", seriesCount);
	Ext.close();
	
	// Each series is a field from the microscope with several cells to crop
	for (series=1; series<=seriesCount; ++series) {
		run("Bio-Formats Importer", "open=[" + image_file + "] color_mode=Default rois_import=[ROI manager] " + 
			"specify_range view=Hyperstack   stack_order=XYCZT series_"+series +
			" c_begin_"+series+"=1 c_end_"+series+"=2 c_step_1=1 " + 
			"  z_step_"+series+"=2 " +
			"");
		rename("orig_series");
	
		run("Z Project...", "projection=[Max Intensity] all");
		rename("MIP_Z");
		run("Z Project...", "projection=[Max Intensity]");  // Merge 2 color channels to one channel
		rename("MIP_C");
		close("MIP_Z");
		run("Smooth"); // To connect apicoplasts in cell before thresholding
 		setThreshold(INTENSITY_THRESHOLD, 65535);
		run("Convert to Mask");
		rename("thresh");

		roiManager("reset");
		run("Analyze Particles...", "size=" + MINIMUM_APICOPLAST_AREA + "-Infinity display exclude clear include add");

		// Loop on ROIs and crop to files
		File.makeDirectory(crops_dir_output + "/MIP");
		selectWindow("thresh");
		crop_number = 0;
	    max_crops = roiManager("count");
	    if (MALARIA_MAX_CROPS > 0) {
	    	max_crops = minOf(max_crops, MALARIA_MAX_CROPS);
	    }
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
			print("x, y, CROP_WIDTH, CROP_WIDTH:", x, y, CROP_WIDTH, CROP_WIDTH);
	
			// Load crop
			run("Bio-Formats Importer", "open=[" + image_file + "] color_mode=Default crop " +
				" rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT " + 
				" series_"+series +
	        	" x_coordinate_" + series + "=" + x +" width_" + series + "=" + CROP_WIDTH + 
	        	" y_coordinate_" + series + "=" + y +" height_" + series + "=" + CROP_WIDTH );
	        print("done reading");
	        crop_number += 1;
	        crop_name = "crop_S" + series +"_CROPNUM" + crop_number + ".tif";
	        saveAs("Tiff", crops_dir_output +File.separator+crop_name);

	        // Create a 2D MIP
	        run("Z Project...", "projection=[Max Intensity] all");
	        run("Make Composite");
	        saveAs("png", crops_dir_output + "/MIP/" + crop_name);
	        close();
	        
			close(crop_name);
			close("crop_mip");
			print("Finished crop " + crop_name);
	    } // for crop
	    close("thresh");
	    close("MIP_Z");
	    close("orig_series");
	    print("Finished series " + series);
	} // for series
	print("Finished large image");
}  // end of process_image()



function main() {
	// Ask for root directory from user that contains directories 24h/ and 48h/
	if (!DEBUG) {
		root_dir = getDirectory("Select a directory");
	} else {
		root_dir = "D:\\projects\\michal_shahar\\crop\\240528 cip_ipp2\\";
	}
	print("root_dir", root_dir);

	// Create output directory
	root_base_name = File.getNameWithoutExtension(root_dir);
	root_dir_without_separator = File.getDirectory(root_dir) + root_base_name;
	root_output_dir = root_dir_without_separator + "_crops"; // Created only when script finshes successfully
	root_output_dir_tmp = root_output_dir + "_tmp"; // Renamed at the end of the script to crops_dir_output
	if (File.isDirectory(root_output_dir) && !DEBUG) {
		exit("Directory already exists: " + root_output_dir);
	}
	if (File.isDirectory(root_output_dir_tmp) && !DEBUG) {
		exit("Directory already exists: " + root_output_dir_tmp);
	}
	else {
		File.makeDirectory(root_output_dir_tmp);
	}
	
	// Loop through images
	root_dir_list = getFileList(root_dir);
	for (i = 0; i < root_dir_list.length; i++) {
	    sub_dir = root_dir_list[i];
	    full_sub_dir = root_dir + sub_dir;
	    if (File.isDirectory(full_sub_dir)) {
	        print("Processing directory: " + full_sub_dir);
	        subList = getFileList(full_sub_dir);
	        for (j = 0; j < subList.length; j++) {
	            image_file = full_sub_dir + subList[j];
	            if (endsWith(image_file, ".nd2")) {
				    basename = File.getNameWithoutExtension(image_file);
				    subdir_output = root_output_dir_tmp + File.separator + sub_dir;
				    crops_dir_output = subdir_output + basename + "_crops";  
					print("crops_dir_output:", crops_dir_output);
					File.makeDirectory(subdir_output);
					File.makeDirectory(crops_dir_output);
					process_image(image_file, crops_dir_output);
				}
	        }
	    }
	}
	
	// This signals the shell script that this script finished successfully
	print("renaming " + root_output_dir_tmp + " to " + root_output_dir);
	rename_ok = File.rename(root_output_dir_tmp, root_output_dir);
	waitForUser("Crops saved to " + root_output_dir);
	if (!rename_ok) {
		exit("Could not rename " + root_output_dir_tmp + " to " + root_output_dir);
	}
}


main();