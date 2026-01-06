/*

This imagej Macro works with .tif files and is intended to be used subsequently to Macro: 1_FolderProcessor_LIF_Z-projections.ijm

All folders and subfolders will be screened for MaxZ.tif and AvZ.tif files. 

If these files are detected, a subdirectory with the name "Masks_Intensities_" will be created (or "Masks_Intensities_" + index, if the file name already exists). 

The files will be opened and processed using the following functions:
			processFiles(directory);
			analyzeImage();	

This will be continued until all MaxZ.tif and AvZ.tif files in the selected folder and subfolders have been processed. 

author: Filip Liebsch, 2022

*/



//setup
run("Set Measurements...", "area mean min integrated");
setOption("BlackBackground", true);

chosenDir = getDirectory("chose a directory");
processFiles(chosenDir);

function processFiles(directory) {

	fileList = getFileList(directory);

	outputDirName = directory + "Masks_Intensities";

	folderCount = 1;
	while (File.exists(outputDirName)) {
		print(outputDirName + " exists");
		outputDirName = directory + "Masks_Intensities_" + folderCount;
		folderCount++;
	}
	
	outputDirPath = outputDirName + File.separator;
	
	for (file = 0; file < fileList.length; file++) {
		if (endsWith(fileList[file], "MaxZ.tif")) {
			File.makeDirectory(outputDirName);
			open(directory + fileList[file]);
			open(directory + "AvZ.tif");
			analyzeImage();	
		} else if (endsWith(fileList[file], "/") && !matches(fileList[file], ".*Masks_Intensities.*")) {
			processFiles(directory + fileList[file]);
		}
	}
}

function analyzeImage() {	

	//Split and rename channels
	selectWindow("MaxZ.tif");
	run("Split Channels");
	selectWindow("C1-MaxZ.tif");
	rename("CellMaxZ.tif");
	selectWindow("C2-MaxZ.tif");
	rename("GphnMaxZ.tif");
	selectWindow("C3-MaxZ.tif");
	rename("alpha2MaxZ.tif");
	selectWindow("C4-MaxZ.tif");
	rename("alpha1MaxZ.tif");

	selectWindow("AvZ.tif");
	run("Split Channels");
	selectWindow("C1-AvZ.tif");
	rename("CellAvZ.tif");
	selectWindow("C2-AvZ.tif");
	rename("GphnAvZ.tif");
	selectWindow("C3-AvZ.tif");
	rename("alpha2AvZ.tif");
	selectWindow("C4-AvZ.tif");
	rename("alpha1AvZ.tif");

	//Soma mask
	selectWindow("CellMaxZ.tif");
	rename("SomaMask.tif");
	run("Median...", "radius=10");
	run("Enhance Contrast...", "saturated=0.3 normalize");	
	run("Auto Threshold", "method=Otsu white");
	save(outputDirPath + "SomaMask.tif");
	selectWindow("SomaMask.tif");
	run("Create Selection");
	roiManager("Add");
	roiManager("Select", 0);
	roiManager("Rename", "Soma");


	//alpha2 mask
	selectWindow("alpha2MaxZ.tif");
	rename("alpha2Mask.tif");
	run("Subtract Background...", "rolling=30");
	run("Auto Threshold", "method=Otsu white");//
	run("Watershed");
	save(outputDirPath + "alpha2Mask.tif");
		//substract background
		selectWindow("alpha2Mask.tif");
		run("Create Selection");
		roiManager("Add");
		roiManager("Select", 1);
		roiManager("Rename", "alpha2");
		roiManager("Select", 1);
		run("Make Inverse");
		roiManager("Add");
		roiManager("Select", 2);
		roiManager("Rename", "alpha2_bckgrd");
		selectWindow("alpha2AvZ.tif");
		rename("alpha2Intensity.tif");
		roiManager("Select", 2);
	bckgrd_alpha2 = getValue("Mean");
	run("Select None");
	run("Subtract...", "value=" + bckgrd_alpha2);
	save(outputDirPath + "alpha2Intensity.tif");

	//alpha1 mask
	selectWindow("alpha1MaxZ.tif");
	rename("alpha1Mask.tif");
	run("Subtract Background...", "rolling=30");
	run("Auto Threshold", "method=Otsu white");//
	run("Watershed");
	save(outputDirPath + "alpha1Mask.tif");
		//substract background
		selectWindow("alpha1Mask.tif");
		run("Create Selection");
		roiManager("Add");
		roiManager("Select", 3);
		roiManager("Rename", "alpha1");
		roiManager("Select", 3);
		run("Make Inverse");
		roiManager("Add");
		roiManager("Select", 4);
		roiManager("Rename", "alpha1_bckgrd");
		selectWindow("alpha1AvZ.tif");
		rename("alpha1Intensity.tif");
		roiManager("Select", 4);
		bckgrd_alpha1 = getValue("Mean");
		run("Select None");
		run("Subtract...", "value=" + bckgrd_alpha1);
		save(outputDirPath + "alpha1Intensity.tif");

	//Gphn mask
	selectWindow("GphnMaxZ.tif");
	rename("GphnMask.tif");
	run("Duplicate...", " ");
	rename("GphnMaskSoma.tif");
	run("Invert");
	roiManager("Select", 0);
	run("Clear Outside");
	run("Select None");
	run("Invert");
	//Convoluted Background Subtraction
	run("Duplicate...", " ");
	rename("GphnMaskSomaDiff.tif");
	run("Median...", "radius=50"); //50
	run("Maximum...", "radius=7.5"); //maximum filter with the factor (1.5*(radius/10))
	imageCalculator("Subtract", "GphnMaskSoma.tif","GphnMaskSomaDiff.tif");
	close("GphnMaskSomaDiff.tif");
	
	selectWindow("GphnMaskSoma.tif");
	run("Median...", "radius=3");
	run("Subtract Background...", "rolling=50");
	run("Auto Threshold", "method=Otsu white");	
	run("Create Selection");
	roiManager("Add");
	roiManager("Select", 5);
	roiManager("Rename", "SomClus");
	roiManager("Select", newArray(0,5));
	roiManager("XOR");
	roiManager("Add");
	roiManager("Select", 6);
	roiManager("Rename", "diffSom");
	close("GphnMaskSoma.tif");
	
	selectWindow("GphnMask.tif");
	roiManager("Select", 6);
	SomGeph = getValue("Mean");
	run("Select None");
	run("Subtract...", "value=" + SomGeph);
	
	run("Duplicate...", " ");
	rename("GphnDiff.tif");
	run("Median...", "radius=50");
	run("Maximum...", "radius=7.5");
	imageCalculator("Subtract", "GphnMask.tif","GphnDiff.tif");
	close("GphnDiff.tif");
	selectWindow("GphnMask.tif");
	run("Median...", "radius=3");
	run("Subtract Background...", "rolling=50");
	run("Auto Threshold", "method=Otsu white");
	run("Watershed");
	save(outputDirPath + "GphnMask.tif");

	//substract diffuse somatic Gphn mScarlet
	selectWindow("GphnMask.tif");
	run("Create Selection");
	roiManager("Add");
	roiManager("Select", 7);
	roiManager("Rename", "Clusters");

	roiManager("Select", newArray(0,7));
	roiManager("AND");
	roiManager("Add");
	roiManager("Select", 8);
	roiManager("Rename", "somaticClusters");

	roiManager("Select", newArray(0,8));
	roiManager("XOR");
	roiManager("Add");
	roiManager("Select", 9);
	roiManager("Rename", "diffuseSoma");

	selectWindow("GphnAvZ.tif");
	rename("GphnIntensity.tif");
	roiManager("Select", 9);
	diffGphn = getValue("Mean");
	run("Select None");
	run("Subtract...", "value=" + diffGphn);
	save(outputDirPath + "GphnIntensity.tif");
	
	roiManager("Save", outputDirPath+"SomaROIs.zip");
	selectWindow("ROI Manager");
    run("Close");

	close("GphnMask.tif");
	close("GphnIntensity.tif");
	close("alpha1Intensity.tif");
	close("alpha2Intensity.tif");
	
	close("CellAvZ.tif");
	close("alpha1Mask.tif");
	close("alpha2Mask.tif");
	close("SomaMask.tif");

}





