// Analyze crop images. 
// Segment the apicoplast and measure. Get the mean intensity and volume.

// TODO
// - Mean intensity

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

run("3D Manager");
Ext.Manager3D_Reset();

filelist = getFileList(crops_dir);
for (crop_file_i = 0; crop_file_i < lengthOf(filelist); crop_file_i++) {
    crop_image_name = filelist[crop_file_i];
    print("crop_image_name:", crop_image_name);
    if (endsWith(crop_image_name, ".tif")) { 
		crop_image_basename = File.getNameWithoutExtension(crop_image_name);
//    	series = replace(crop_image_basename, "crop_S(\\d{1,8})_.*", "$1");  // this doesnt seem to change crop_image_basename
//    	// see: https://forum.image.sc/t/using-regex-to-extract-substrings-in-imagej-macro-language/89049/4
//    	crop_num = replace(crop_image_basename, "crop_S\\d{1,8}_CROPNUM(\\d{1,8}).*", "$1");
		print("crop_image_basename:", crop_image_basename);
//		print("series:", series);
//		print("crop_num:", crop_num);
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
				// Prepcrocess before segmentation
				run("Median...", "radius=3 stack");
				// Segmentation
				setThreshold(APICOPLAST_THRESHOLD,65535);
				run("Convert to Mask", "background=Dark black create stack");
				rename("MASK_crop_" + cur_frame_name);
				// Measure 3D object

			    run("3D Manager Options", "volume integrated_density ");
				// run the manager 3D and add image
				
				Ext.Manager3D_AddImage();
				// https://mcib3d.frama.io/3d-suite-imagej/uploads/MacrosFunctionsRoiManager3D.pdf
				
				Ext.Manager3D_Count(nb_obj);
				print("number of objects",nb_obj);
				if (nb_obj > 0) {
					for (object=0; object<nb_obj;object++) {
						Ext.Manager3D_Select(object);
						Ext.Manager3D_GetName(0, obj_name);
						Ext.Manager3D_Rename(cur_frame_name + "_" + obj_name);
					}
				}
				Ext.Manager3D_Measure();
				
				// Save
				Ext.Manager3D_SaveResult("M",spreadsheets_dir + "/"+ crop_image_basename + "_"+ cur_frame_name +".csv");
				Ext.Manager3D_CloseResult("M");
				Ext.Manager3D_Reset();
				close(cur_frame_name);
				close("MASK_crop_" + cur_frame_name);
			} // frame
			
		} // channel
        close("cur_crop_all_dims");
    }
}
waitForUser("done script");