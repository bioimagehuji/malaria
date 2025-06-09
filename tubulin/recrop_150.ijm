dir = getDirectory("Select the source directory with images");
list = getFileList(dir);

width = 60;  // Width of crop
height = 60; // Height of crop
x = 45;      // Centered crop: (150 - 60) / 2
y = 45;      // Centered crop: (150 - 60) / 2
last_frame = 20; // Number of last frame to keep

outputDir = dir + "cropped/";
File.makeDirectory(outputDir);

for (i = 0; i < list.length; i++) {
    if (endsWith(list[i], ".tif") ) {
        // Use Bio-Formats open command to crop during import
        cmd = "open=[" + dir + list[i] + "] " +
              "autoscale color_mode=Default view=Hyperstack " +
              "stack_order=XYCZT specify_range t_begin=1 t_end=" + last_frame + " " +
              "crop x_coordinate_1=" + x + " y_coordinate_1=" + y +
              " width_1=" + width + " height_1=" + height;
        run("Bio-Formats Importer", cmd);
        saveAs("Tiff", outputDir + list[i]);
        close();
    }
}
