// Analyze crop images.
// This script segments the apicoplast, nucleus and tubulin. 
// The number of objects and their volumes is measured and saved in files beginning with "M_".
// Also, the distance between all objects is measured and saved in files beginning with "D_".
// Plugin requirements:
// - 3D ImageJ Suite. Installed through FIJI Updcate. Developers: https://mcib3d.frama.io/3d-suite-imagej/


CH1_APICOPLAST_THRESHOLD = 700;
CH2_NUCLEUS_THRESHOLD = 1000;
CH3_TUBULIN_THRESHOLD = 600;
DEBUG = false;

close("*");
run("Clear Results");
print("\\Clear");

// Ask user to choose a directory with images of crops
if (DEBUG==false) {
	crops_dir = getDirectory("Choose directory with nd2 images");
} 
else {
	call("java.lang.System.getenv", "MALARIA_DIRECTORY"); // .../tub_202506
}


print("crops_dir:", crops_dir);
spreadsheets_dir = crops_dir + "/spreadsheets";
File.makeDirectory(spreadsheets_dir);

run("3D Manager");
Ext.Manager3D_Reset();
run("3D Manager Options", "volume surface integrated_density");


filelist = getFileList(crops_dir);
for (crop_file_i = 0; crop_file_i < lengthOf(filelist); crop_file_i++) {
	showProgress(crop_file_i, lengthOf(filelist));
    crop_image_name = filelist[crop_file_i];
    print("crop_image_name:", crop_image_name);
    if (endsWith(crop_image_name, ".nd2")) { 
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
			print("DEBUG frames = 4");
			frames = 4;
		}
		// Open crop
		run("Bio-Formats Importer", "open=" + crop_image_path + " color_mode=Default rois_import=[ROI manager] " +
				"view=Hyperstack stack_order=XYCZT  ");
		rename("cur_crop_all_dims");
		print("filename:", crop_image_path);
		// Open each channel except the last
		for (frame=1; frame<=frames; frame++ ) {
			print("frame:", frame);
			for (channel=1; channel<channels; channel++ ) {
				print("ch", channel);

				// Open
				cur_frame_channel_name = "C" + channel + "_T"+frame;
				selectImage("cur_crop_all_dims");
				run("Duplicate...", "title=" + cur_frame_channel_name + " duplicate channels=" + channel + " frames=" + frame);
				// Prepcrocess before segmentation
				//         run("Median...", "radius=3 stack"); // Removed because smoothed too much and added minimum object size in colab
				
				// Segmentation
				if (channel==1) {
					setThreshold(CH1_APICOPLAST_THRESHOLD,65535);
				} else if (channel==2) {
					setThreshold(CH2_NUCLEUS_THRESHOLD,65535);
				} else if (channel==3) {
					setThreshold(CH3_TUBULIN_THRESHOLD,65535);
				}
				run("Convert to Mask", "background=Dark black create stack");
				masked_crop = "MASK_crop_" + cur_frame_channel_name;
				rename(masked_crop);
				print("masked_crop:", masked_crop);

				// Measure number of objects (3D connected components)
				//
				selectImage(masked_crop);
//				Ext.Manager3D_Reset();
				Ext.Manager3D_Segment(128, 255);
				Ext.Manager3D_AddImage();
				run("3D Manager");  // update to see the objects in the manager
				
				im_name_for_num_of_obj = cur_frame_channel_name+"_3dseg";
				rename(im_name_for_num_of_obj);
				Ext.Manager3D_Count(nb_obj);
				print("number of objects",nb_obj);
				if (nb_obj > 0) {
					for (object=0; object<nb_obj;object++) {
						Ext.Manager3D_Select(object);
						Ext.Manager3D_GetName(object, obj_name);
						print("object, obj_name " + object + " " + obj_name);
						if (startsWith(obj_name, "obj")) {
							Ext.Manager3D_Rename(cur_frame_channel_name + "_" + obj_name);
							print("renamed to: " + cur_frame_channel_name + "_" + obj_name);
						}
					}
				}
			}
			Ext.Manager3D_DeselectAll(); // to measure all objects
			Ext.Manager3D_Measure();
			print(spreadsheets_dir + "/"+ crop_image_basename + "_"+ cur_frame_channel_name +"_objects.csv");
			Ext.Manager3D_SaveResult("M",spreadsheets_dir + "/"+ crop_image_basename + "_T"+frame +"_objects.csv");
			Ext.Manager3D_CloseResult("M");
			
			Ext.Manager3D_Distance();
			Ext.Manager3D_SaveResult("D",spreadsheets_dir + "/"+ crop_image_basename + "_T"+frame +"_objects.csv");
			Ext.Manager3D_CloseResult("D");
			Ext.Manager3D_Reset();
			
			for (channel=1; channel<channels; channel++ ) {
				cur_frame_channel_name = "C" + channel + "_T"+frame;
				im_name_for_num_of_obj = cur_frame_channel_name+"_3dseg";
				close(im_name_for_num_of_obj);
				masked_crop = "MASK_crop_" + cur_frame_channel_name;
				close(masked_crop);
				close(cur_frame_channel_name);
			}
		}
        close("cur_crop_all_dims");
    }
}

waitForUser("Result saved in:" + spreadsheets_dir);