// Analyze crop image. Get the mean intensity of the apicoplast.
APICOPLAST_THRESHOLD = 500;
DEBUG = true;

close("*");
run("Clear Results");
print("\\Clear");

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
crops_dir = dirname + File.separator + basename + "_crops";
print("crops_dir:", crops_dir);


spreadsheets_dir = crops_dir + "/spreadsheets";
File.makeDirectory(spreadsheets_dir);

filelist = getFileList(crops_dir);
for (crop_i = 0; crop_i < lengthOf(filelist); crop_i++) {
    crop_image_name = filelist[crop_i];
    if (endsWith(crop_image_name, ".tif")) { 
		crop_image_path = crops_dir + "/" + crop_image_name;
        print("crop_image_path:", crop_image_path);
        // Open large 5D image virtually to get the number of frames
        run("Bio-Formats Importer", "open="  + crop_image_path + 
        	" color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT use_virtual_stack");
		getDimensions(width, height, channels, slices, frames);
		print(width, height, channels, slices, frames);
		close();
		if (DEBUG) {
			frames = 2;
		}
		// Open crop
		run("Bio-Formats Importer", "open=" + crop_image_path + " color_mode=Default rois_import=[ROI manager] " +
				"view=Hyperstack stack_order=XYCZT  ");
		rename("cur_crop_all_dims");
		print(crop_image_path);
		// Open each channel except the last
		for (channel=1; channel<channels; channel++ ) {
			print("ch", channel);
			for (frame=1; frame<=frames; frame++ ) {
				print("frame:", frame);
				// Open
				cur_frame_name = "C" + channel + "_T"+frame;
				run("Duplicate...", "title=" + cur_frame_name + " duplicate channels=" + channel + " frames=" + frame);
				run("Median...", "radius=3 stack");
				setThreshold(APICOPLAST_THRESHOLD,65535);
				run("Convert to Mask", "background=Dark black create stack");
				rename("MASK_crop_" + cur_frame_name);
				run("3D Volume");
				crop_image_basename = File.getNameWithoutExtension(crop_image_name);
				saveAs("Results", spreadsheets_dir + "/"+ crop_image_basename + "_"+ cur_frame_name +".csv");
				close("crop_CT");
				close("MASK_crop_" + cur_frame_name);
				run("Clear Results");
			//	return;
			} // frame
		} // channel
        close("cur_crop_all_dims");
    } 
}