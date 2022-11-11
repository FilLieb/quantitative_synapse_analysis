/*

This imagej Macro works with .tif files and is intended to be used subsequently to Macro: 

1_FolderProcessor_LIF_Z-projections.ijm
2_FolderProcessor_TIF_fDIO_a1_a2_Masks

All folders and specified subfolders (i.e. "Masks_Intensities") will be screened for alpha1Intensity.tif files. 

If these files are detected, a subdirectory with the name "mScarlet-Gphn_Analysis_" will be created (or "alpha1_Analysis_" + index, if the file name already exists). 

The files will be opened and processed using the following functions:
			processFiles(directory);
			analyzeImage();

This will be continued until all  specified .tif the selected folder and specified subfolders have been processed. 

author: Filip Liebsch, 2022

*/


//setup
run("Set Measurements...", "area mean min integrated decimal=4");
setOption("BlackBackground", true);

chosenDir = getDirectory("chose a directory");
processFiles(chosenDir);

function processFiles(directory) {

	fileList = getFileList(directory);

	outputDirName = directory + "alpha1_Analysis_";//

	folderCount = 1;
	
	while (File.exists(outputDirName)) {
		print(outputDirName + " exists");
		outputDirName = directory + "alpha1_Analysis_" + folderCount; //
		folderCount++;
	}
	
	outputDirPath = outputDirName + File.separator;

	folder = File.getName(directory);
	
	for (file = 0; file < fileList.length; file++) {
		if (endsWith(fileList[file], "alpha1Intensity.tif") && folder == "Masks_Intensities") {
			File.makeDirectory(outputDirName);
			open(directory + fileList[file]);
			open(directory + "alpha1Mask.tif");
			open(directory + "GphnIntensity.tif");
			open(directory + "GphnMask.tif");
			open(directory + "alpha2Intensity.tif");
			open(directory + "alpha2Mask.tif");
			analyzeImage();	
			
		} else if (endsWith(fileList[file], "/") && !matches(fileList[file], ".*alpha1_Analysis_.*")) { //
			processFiles(directory + fileList[file]);
		}
	}
}

function analyzeImage() {	
	//individual alpha1 clusters//
	selectWindow("alpha1Mask.tif");//
	run("Select None");
	run("Analyze Particles...", "size=0-Infinity exclude clear add");
	close("alpha1Mask.tif");//

	roiNumber = roiManager("count");
	run("Clear Results");	
	
	for (m = 0; m < roiNumber; m++) {
		selectWindow("GphnIntensity.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		setResult("MeanIntensityGphn", m, mean);
		setResult("MaxIntensityGphn", m, max);

		selectWindow("alpha1Intensity.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		setResult("ClusterSize", m, area); //
		setResult("MeanIntensityAlpha1", m, mean);
		setResult("MaxIntensityAlpha1", m, max);

		selectWindow("alpha2Intensity.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		setResult("MeanIntensityAlpha2", m, mean);
		setResult("MaxIntensityAlpha2", m, max);

		//classification
		selectWindow("GphnMask.tif");//
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		if (mean > 1) {
			setResult("Gphn", m, "positive");//
		} else {
			setResult("Gphn", m, "negative");//
		}

		selectWindow("alpha2Mask.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		if (mean > 1) {
			setResult("alpha2", m, "positive");
		} else {
			setResult("alpha2", m, "negative");
		}
		
		maskpath = File.getParent(directory);
		cellpath = File.getParent(maskpath);
		cell = File.getName(cellpath);
		
		condpath = File.getParent(cellpath);
		cond = File.getName(condpath);
		
		datepath = File.getParent(condpath);
		date = File.getName(datepath);
	
		setResult("Date", m, date);
		setResult("Condition", m, cond);
		setResult("Cell", m, cell);
		
	}
	
	saveAs("Results", outputDirPath+"ClusterAnalysis_"+ cond + cell + ".tsv");
	
	close("alpha1Intensity.tif");
	close("alpha2Intensity.tif");
	close("GphnIntensity.tif");
	
	close("GphnMask.tif"); //
	close("alpha2Mask.tif");
	
	//save
	roiManager("Save", outputDirPath+"RoiSetGphnClusters.zip");
	selectWindow("ROI Manager");
    run("Close");

}

