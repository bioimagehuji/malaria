// Analyze crop image. Get the mean intensity of the apicoplast.
THRESHOLD = 500;
DEBUG = true;

close("*");
run("Clear Results");


crops_dir = getDirectory("Choose crops dir");
print("crops_dir:", crops_dir);
return;
spreadsheets_dir = crops_dir + "/spreadsheets";
File.makeDirectory(spreadsheets_dir);

filelist = getFileList(crops_dir);
for (crop_i = 0; crop_i < lengthOf(filelist); crop_i++) {
    crop_image_name = filelist[crop_i];
    if (startsWith(crop_image_name, "cell_3d_") && endsWith(crop_image_name, ".tif")) { 
		crop_image_path = crops_dir + "/" + crop_image_name;
        print("crop_image_path:", crop_image_path);
        // Open large 5D image virtually to get the number of frames
        run("Bio-Formats Importer", "open="  + crop_image_path + 
        	" color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT use_virtual_stack");
		getDimensions(width, height, channels, slices, frames);
		print(width, height, channels, slices, frames);
		close();
		if (DEBUG) {
			frames = 1;
		}
		
		// Open each channel except the last
		for (channel=1; channel<channels; channel++ ) {
			// Open and split the frames
			run("Bio-Formats Importer", "open=" + crop_image_path + " color_mode=Default rois_import=[ROI manager] " +
				"specify_range split_timepoints view=Hyperstack stack_order=XYCZT  " +
				" c_begin=" + channel + " c_end=" + channel + " c_step=1  t_begin=1 t_end=" + frames +" t_step=1");
//			waitForUser("ch" + channel);
			for (frame=0; frame<frames; frame++ ) {
				selectImage(crop_image_path + " - T=" + frame);
				cur_frame_name = "C" + channel + "_T"+frame;
				rename(cur_frame_name);
				run("Median...", "radius=3 stack");
				//	run("3D Objects Counter", "threshold=423 slice=4 min.=10 max.=337500 exclude_objects_on_edges objects surfaces centroids centres_of_masses statistics summary");
				setThreshold(THRESHOLD,65535);
				run("Convert to Mask", "background=Dark black create stack");
	//			run("3D Intensity Measure", 
	//				"objects=MASK_" + cur_frame_name + " signal=" + cur_frame_name);
				run("3D Volume");
				crop_image_basename = File.getNameWithoutExtension(crop_image_name);
				saveAs("Results", spreadsheets_dir + "/"+ crop_image_basename + "_"+ cur_frame_name +".csv");
				
				close(cur_frame_name);
				
				close("MASK_" + cur_frame_name);
				
				run("Clear Results");
			//	return;
			} // frame
		} // channel
        
    } 
}



