/*

This imagej Macro works with .tif files and is intended to be used subsequently to Macro: 

1_FolderProcessor_LIF_Z-projections.ijm
2_FolderProcessor_TIF_fDIO_mEGFP_mScarlet_Masks.ijm

All folders and specified subfolders (i.e. "Masks_Intensities_2") will be screened for mEGFPGphnIntensity.tif files. 

If these files are detected, a subdirectory with the name "mEGFP-Gphn_Analysis_" will be created (or "mEGFP-Gphn_Analysis_" + index, if the file name already exists). 

The files will be opened and processed using the following functions:
			processFiles(directory);
			analyzeImage();

This will be continued until all  specified .tif the selected folder and specified subfolders have been processed. 

author: Filip Liebsch, 2022

*/


//setup
run("Set Measurements...", "area mean min integrated decimal=4");
setOption("BlackBackground", true);

//program
chosenDir = getDirectory("chose a directory");
processFiles(chosenDir);

//functions
//processFiles function screens folder and specified subfolders, creates directories, and opens .tif files with the specified names
function processFiles(directory) {

	fileList = getFileList(directory);

	outputDirName = directory + "mEGFP-Gphn_Analysis_";//name of the newly created subfolder

	folderCount = 1;
	
	while (File.exists(outputDirName)) {
		print(outputDirName + " exists");
		outputDirName = directory + "mEGFP-Gphn_Analysis_" + folderCount; //when a subfolder from a previous analysis exists, a new folder with underscore and index will be created. 
		folderCount++;
	}
	
	outputDirPath = outputDirName + File.separator;

	folder = File.getName(directory);
	
	for (file = 0; file < fileList.length; file++) {
		if (endsWith(fileList[file], "mEGFPGphnIntensity.tif") && folder == "Masks_Intensities_2") { //Only specific subfolders will be analyzed, i.e. images in subfolders named "Mask_Intensities_2"
			File.makeDirectory(outputDirName);
			open(directory + fileList[file]);
			open(directory + "mEGFP.tif");
			open(directory + "mScarletGphnIntensity.tif");
			open(directory + "mScarlet.tif");
			open(directory + "Soma.tif");
			open(directory + "vGATIntensity.tif");
			open(directory + "vGAT.tif");
			analyzeImage();	
			
		} else if (endsWith(fileList[file], "/") && !matches(fileList[file], ".*mEGFP-Gphn_Analysis_.*")) {
			processFiles(directory + fileList[file]);
		}
	}
}

/*
analyzeImage function will use the previously generated mEGFP-Gphn mask (mEGFP.tif) and with the imagej Analyze Particles algorithm, individual rois will be created.
The distance between the center of these ROIs (mEGFP-Gphn clusters) and the center of the soma will be measured.
Additionally, mEGFP-, mScarlet-, and vGAT intensities in these ROIs will be measured (based on the background subtracted Average Z projections of the respective channels). 
Every individual ROI (mEGFP-Gphn) cluster will be classified as "negative" or "positive" for vGAT, mScarlet, or Soma, based on their overlap with the respective masks. 

Date, Cell, and Condition will be read from folder and subfolder organization.

Data will be written in an organized "semi-tidy" table (one line per mEGFP-Gphn cluster). 

Results table, will be saved as .tsv file with the file name "Co-ClusterAnalysis_"+ Name of the splice variant + number of the cell. 

The RoiManager will be saved as "RoiSetEGFPClusters.zip"
*/

function analyzeImage() {	
	//coordinates of Soma Center
	selectWindow("Soma.tif");//
	run("Invert");
	run("Select None");
	run("Analyze Particles...", "size=25-Infinity exclude clear add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "Soma");
	
	roiManager("Select", "Soma");
	centerSomaX = getValue("X"); //calibrated X value of the center of the Soma will be saved
	centerSomaY = getValue("Y"); //calibrated Y value of the center of the Soma will be saved

	selectWindow("ROI Manager");
    run("Close");

	//individual Gphn mEGFP clusters
	selectWindow("mEGFP.tif");//
	run("Invert");
	run("Select None");
	run("Analyze Particles...", "size=0-Infinity exclude clear add");
	close("mEGFP.tif");//

	roiNumber = roiManager("count");
	run("Clear Results");	

	//analysis of individual ROIs
	for (m = 0; m < roiNumber; m++) {

	//intensity measurements
		//intensity of mEGFP signal
		selectWindow("mEGFPGphnIntensity.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		setResult("ClusterSize", m, area);
		setResult("MeanIntensitymEGFPGphn", m, mean);
		setResult("MaxIntensitymEGFPGphn", m, max);

		//intensity of mScarlet signal
		selectWindow("mScarletGphnIntensity.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		setResult("MeanIntensitymScarletGphn", m, mean);
		setResult("MaxIntensitymScarletGphn", m, max);

		//intensity of vGAT signal
		selectWindow("vGATIntensity.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		setResult("MeanIntensityvGAT", m, mean);
		setResult("MaxIntensityvGAT", m, max);

	//classification of individual clusters
		//mScarlet
		selectWindow("mScarlet.tif");//
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		if (mean > 1) {
			setResult("mScarletGphn", m, "positive");
		} else {
			setResult("mScarletGphn", m, "negative");
		}

		//vGAT
		selectWindow("vGAT.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		if (mean > 1) {
			setResult("vGAT", m, "positive");
		} else {
			setResult("vGAT", m, "negative");
		}

		//Soma
		selectWindow("Soma.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		if (mean > 1) {
			setResult("Soma", m, "positive");
		} else {
			setResult("Soma", m, "negative");
		}

		//getting the names of the cell, condition, and date from the folder tree
		maskpath = File.getParent(directory); //in the parent of the directory (masks and intensities are saved here) Z-projections are saved
		cellpath = File.getParent(maskpath); //in the parent of the Z-projections .lif files are saved and the folder has the "name" of the cell
		cell = File.getName(cellpath); //the "name of the cell" will be saved in the variable cell 
		
		condpath = File.getParent(cellpath); //cells are saved in a folder that carries the "name" of the condition
		cond = File.getName(condpath); //the "name of the condition" will be saved in the variable cond 
		
		datepath = File.getParent(condpath); //conditions are saved in a folder that carries the date of the experiment
		date = File.getName(datepath); //the date will be saved in the variable date


		//distances
		roiManager("Select", m);

		centerClusX = getValue("X"); //calibrated X value of the center of the Cluster will be saved
		centerClusY = getValue("Y"); //calibrated Y value of the center of the Cluster will be saved

		distanceX = abs(centerClusX - centerSomaX); //distance in X will be calculated
		distanceY = abs(centerClusY - centerSomaY); //distance in Y will be calculated 

		distance = sqrt(pow(distanceX, 2) + pow(distanceY, 2)); //distance will be calculated based on Pythagora's theorem
		setResult("DistanceCenter", m, distance);		

		//the last columns in the Results table will be filled with the date, condition and name of the cell
		setResult("DistanceCenter", m, distance);		
		setResult("Date", m, date);
		setResult("Condition", m, cond);
		setResult("Cell", m, cell);
		
	}
	
	saveAs("Results", outputDirPath+"Co-ClusterAnalysis_"+ cond + cell + ".tsv");
	
	close("mEGFPGphnIntensity.tif");
	close("mScarletGphnIntensity.tif");
	
	close("mScarlet.tif");
	close("Soma.tif");
	
	close("vGATIntensity.tif");
	close("vGAT.tif");

	//save
	roiManager("Save", outputDirPath+"RoiSetEGFPClusters.zip");
	selectWindow("ROI Manager");
    run("Close");


}

