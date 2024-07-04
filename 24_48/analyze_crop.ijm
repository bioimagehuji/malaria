// Analyze crop images.
// Segment the apicoplast and measure. Measure the number of objects and volume.
// 
// Plugin requirements:
// - 3D ImageJ Suite. Installed through FIJI Updcate. Developers: https://mcib3d.frama.io/3d-suite-imagej/


APICOPLAST_THRESHOLD = 500;
DEBUG = true;

MALARIA_DIRECTORY = call("java.lang.System.getenv", "MALARIA_DIRECTORY");
print("MALARIA_DIRECTORY: " + MALARIA_DIRECTORY);


close("*");
run("Clear Results");
print("\\Clear");


function analyze_crop(crop_image_path, spreadsheet_file_prefix) {
	crop_results = newArray(2); // Returned results
	
	run("3D Manager");
	Ext.Manager3D_Reset();
	// Open crop
	run("Bio-Formats Importer", "open=[" + crop_image_path + "] color_mode=Default rois_import=[ROI manager] " +
			"view=Hyperstack stack_order=XYCZT  ");
	getDimensions(width, height, channels, slices, frames);
	print(width, height, channels, slices, frames);
	rename("cur_crop_all_dims");
	// Open each channel except the last
	for (channel=1; channel<channels; channel++ ) {
		print("ch", channel);
		// Open
		cur_frame_name = "C" + channel;
		run("Duplicate...", "title=" + cur_frame_name + " duplicate channels=" + channel );

		// Prepcrocess before segmentation
		run("Median...", "radius=3 stack");
		
		// Segmentation
		setThreshold(APICOPLAST_THRESHOLD,65535);
		run("Convert to Mask", "background=Dark black create stack");
		masked_crop = "MASK_crop_" + cur_frame_name;
		rename(masked_crop);
		print("masked_crop:", masked_crop);

		// Measure number of objects (3D connected components)
		//
		run("3D Manager Options", "volume integrated_density ");
		selectImage(masked_crop);
		Ext.Manager3D_Reset();
		Ext.Manager3D_Segment(128, 255);
		Ext.Manager3D_AddImage();
		run("3D Manager");  // update to see the objects in the manager
		
		im_name_for_num_of_obj = cur_frame_name+"_3dseg";
		rename(im_name_for_num_of_obj);

		Ext.Manager3D_DeselectAll(); // to measure all objects
		Ext.Manager3D_Measure();
		Ext.Manager3D_SaveResult("M",spreadsheet_file_prefix + "_"+ cur_frame_name +".csv");
		Ext.Manager3D_CloseResult("M");
		
		Ext.Manager3D_Reset();
		close(im_name_for_num_of_obj);
		close(masked_crop);
		close(cur_frame_name);
	
	} // for channel
    close("cur_crop_all_dims");
//	waitForUser("Result saved in:" + spreadsheet_file_prefix);
}


function main() {
	// Ask for root directory from user that contains directories 24h/ and 48h/
	if (!DEBUG) {
		root_dir = getDirectory("Select a root directory that contains sub-directories 24h and 48h");
	} else {
//		root_dir = MALARIA_DIRECTORY;
		root_dir = "D:\\projects\\michal_shahar\\crop\\240528 cip_ipp2_crops\\";
	}
	print("root_dir", root_dir);

	// Create output root directory
	root_base_name = File.getNameWithoutExtension(root_dir);
	root_dir_without_separator = File.getDirectory(root_dir) + root_base_name;
	root_output_dir = root_dir_without_separator + "_spreadsheets"; // Created only when script finshes successfully
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
	    	File.makeDirectory(root_output_dir_tmp + File.separator + sub_dir);
	        print("  sub directory: " + full_sub_dir);
	        subList = getFileList(full_sub_dir);
	        for (j = 0; j < subList.length; j++) {
	            crops_dir = subList[j];
	            full_crops_dir = full_sub_dir + crops_dir;
	            if (File.isDirectory(full_crops_dir)) {
	            	output_image_crops_dir = root_output_dir_tmp + File.separator + sub_dir + File.separator + crops_dir;
	            	File.makeDirectory(output_image_crops_dir);
	            	print("    full_crops_dir: " + full_crops_dir);
	        		crops_list = getFileList(full_crops_dir);
        			for (k = 0; k < crops_list.length; k++) {
        				crop_file = crops_list[k];
        				full_crop_file = full_crops_dir + crop_file;
        				if (endsWith(crop_file, ".tif")) {
        					print("      crop: " + full_crop_file);
        					spreadsheet_file_prefix = output_image_crops_dir + File.separator + File.getNameWithoutExtension(crop_file);
        					print("      spreadsheet_file: " + spreadsheet_file_prefix);
        					analyze_crop(full_crop_file, spreadsheet_file_prefix);
        				}
        			}
				}
	        }
	    }
	}
	
	// This signals the shell script that this script finished successfully
	print("renaming " + root_output_dir_tmp + " to " + root_output_dir);
	rename_ok = File.rename(root_output_dir_tmp, root_output_dir);
	if (!rename_ok) {
		exit("Could not rename " + root_output_dir_tmp + " to " + root_output_dir);
	}
	
	
}


main();
