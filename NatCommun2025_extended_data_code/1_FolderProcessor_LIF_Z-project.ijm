/*

This imagej Macro works with Leica's file format (.lif files).

Lif files are saved in directories with subdirectories, e.g. using folders with the date, subfolders with conditions and subfolders with cell number. 
All folders and subfolders will be screened for .lif files. 

If a .lif file is detected, a subdirectory with the name "Z-projection" will be created (or "Z-projection_" + index, if the file name already exists). 

The file will be opened using the Bio-Formats Reader. 

Every .lif file contains two image stacks: series 1 is the confocal image and series 2 is the image with applied adaptive deconvolution (LIGHTNING). 
Only series 2 will be opened.

MaximumZ and AverageZ projections will be applied and saved as "MaxZ.tif" and "AvZ.tif" in the newly created subfolder.

This will be continued until all .lif files in the selected folder and subfolders have been processed. 

author: Filip Liebsch, 2025

*/


//setup
run("Set Measurements...", "area mean standard modal min centroid center perimeter bounding fit shape feret's integrated median skewness kurtosis area_fraction display redirect=None decimal=3");
setOption("BlackBackground", true);

//program
chosenDir = getDirectory("chose a directory");
processFiles(chosenDir);

function processFiles(directory) {

	fileList = getFileList(directory);

	outputDirName = directory + "Z-projection";

	folderCount = 1;
	while (File.exists(outputDirName)) {
		print(outputDirName + " exists");
		outputDirName = directory + "Z-projection_" + folderCount;
		folderCount++;
	}
	
	outputDirPath = outputDirName + File.separator;
	
	for (file = 0; file < fileList.length; file++) {
		if (endsWith(fileList[file], ".lif")) {
			File.makeDirectory(outputDirName);
			run("Bio-Formats Importer", "open=[" + directory + fileList[file] + "] autoscale color_mode=Composite rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT series_2");
			analyzeImage();	
		} else if (endsWith(fileList[file], "/") && !matches(fileList[file], ".*Z-projection.*")) {
			processFiles(directory + fileList[file]);
		}
	}
}

function analyzeImage() {
	originalImageTitle = getTitle();
	run("Z Project...", "projection=[Max Intensity]");
	rename("MaxZ.tif");
	save(outputDirPath + "MaxZ.tif");
	close("MaxZ.tif");
	
	selectWindow(originalImageTitle);
	run("Z Project...", "projection=[Average Intensity]");
	rename("AvZ.tif");
	save(outputDirPath + "AvZ.tif");
	close(originalImageTitle);
	close("AvZ.tif");
	
}

