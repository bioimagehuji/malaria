// Analyze crop images.
// Segment the apicoplast and measure. Measure the number of objects and volume.
// 
// Plugin requirements:
// - 3D ImageJ Suite. Installed through FIJI Updcate. Developers: https://mcib3d.frama.io/3d-suite-imagej/

// TODO zip spreadsheets

APICOPLAST_THRESHOLD = 500;
DEBUG = false;

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
if (File.isDirectory(crops_dir)) {
	exit("Directory already exists: " + crops_dir);
}
else {
	File.makeDirectory(crops_dir);
}
spreadsheets_dir = crops_dir + "/spreadsheets";
File.makeDirectory(spreadsheets_dir);

run("3D Manager");
Ext.Manager3D_Reset();

filelist = getFileList(crops_dir);
for (crop_file_i = 0; crop_file_i < lengthOf(filelist); crop_file_i++) {
	showProgress(crop_file_i, lengthOf(filelist));
    crop_image_name = filelist[crop_file_i];
    print("crop_image_name:", crop_image_name);
    if (endsWith(crop_image_name, ".tif")) { 
		crop_image_basename = File.getNameWithoutExtension(crop_image_name);
		print("crop_image_basename:", crop_image_basename);
		crop_image_path = crops_dir + "/" + crop_image_name;
        print("crop_image_path:", crop_image_path);
        // Open large 5D image virtually to get the number of frames
        run("Bio-Formats Importer", "open="  + crop_image_path + 
        	" color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT use_virtual_stack");
		getDimensions(width, height, channels, slices, frames);
		print(width, height, channels, slices, frames);
		close();
		if (DEBUG) {
			frames = 4;
		}
		// Open crop
		run("Bio-Formats Importer", "open=" + crop_image_path + " color_mode=Default rois_import=[ROI manager] " +
				"view=Hyperstack stack_order=XYCZT  ");
		rename("cur_crop_all_dims");
		print("filename:", crop_image_path);
		
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
				masked_crop = "MASK_crop_" + cur_frame_name;
				rename(masked_crop);
				print("masked_crop:", masked_crop);

				run("3D Manager Options", "volume integrated_density ");
				
				
				// Measure Volume
				//
				selectImage(masked_crop);
				Ext.Manager3D_Reset();
				Ext.Manager3D_AddImage();
				// see https://mcib3d.frama.io/3d-suite-imagej/uploads/MacrosFunctionsRoiManager3D.pdf
				Ext.Manager3D_Count(nb_obj);
				print("number of objects",nb_obj);
				
				if (nb_obj > 1) {
					exit("Numbner of objects in mask should be 1, but found " + nb_obj);
				}					
				if (nb_obj > 0) {
					Ext.Manager3D_Select(0);
					Ext.Manager3D_GetName(0, obj_name);
					Ext.Manager3D_Rename(cur_frame_name + "_" + obj_name);
					Ext.Manager3D_DeselectAll(); // to measure all objects
					Ext.Manager3D_Measure();
					// Save
					Ext.Manager3D_SaveResult("M",spreadsheets_dir + "/"+ crop_image_basename + "_"+ cur_frame_name +"_volume.csv"); // "M" saves Measure 
					// Source: google: RoiManager3D_2.java
					Ext.Manager3D_CloseResult("M");
				}
				
				// Measure number of objects (3D connected components)
				//
				selectImage(masked_crop);
				Ext.Manager3D_Reset();
				Ext.Manager3D_Segment(128, 255);
				Ext.Manager3D_AddImage();
				run("3D Manager");  // update to see the objects in the manager
				
				im_name_for_num_of_obj = cur_frame_name+"_3dseg";
				rename(im_name_for_num_of_obj);
				Ext.Manager3D_Count(nb_obj);
				print("number of objects",nb_obj);
				if (nb_obj > 0) {
					for (object=0; object<nb_obj;object++) {
						Ext.Manager3D_Select(object);
						Ext.Manager3D_GetName(object, obj_name);
						Ext.Manager3D_Rename(cur_frame_name + "_" + obj_name);
						// debug
//						waitForUser("Manager3D_Rename:" + cur_frame_name + "_" + obj_name );
					}
					Ext.Manager3D_DeselectAll(); // to measure all objects
					Ext.Manager3D_Measure();
					// Save number of objects
					// debug
//					waitForUser("before "+spreadsheets_dir + "/"+ crop_image_basename + "_"+ cur_frame_name +"_objects.csv");
					Ext.Manager3D_SaveResult("M",spreadsheets_dir + "/"+ crop_image_basename + "_"+ cur_frame_name +"_objects.csv");
					// debug
//					waitForUser("after "+spreadsheets_dir + "/"+ crop_image_basename + "_"+ cur_frame_name +"_objects.csv");
					Ext.Manager3D_CloseResult("M");
				}
				
				Ext.Manager3D_Reset();
				close(im_name_for_num_of_obj);
				close(masked_crop);
				close(cur_frame_name);
			} // for frame
		} // for channel
        close("cur_crop_all_dims");
    } // if tif
} // for crop
waitForUser("done script");