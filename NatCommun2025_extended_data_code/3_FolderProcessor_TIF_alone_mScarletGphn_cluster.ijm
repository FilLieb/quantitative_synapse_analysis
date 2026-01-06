/*

This imagej Macro works with .tif files and is intended to be used subsequently to Macro: 

1_FolderProcessor_LIF_Z-project.ijm
2_FolderProcessor_TIF_alone_Masks.ijm

All folders and specified subfolders (i.e. "Masks_Intensities") will be screened for gamma2Intensity.tif files. 

If these files are detected, a subdirectory with the name "mScarlet-Gphn_Analysis_" will be created (or "mScarlet-Gphn_Analysis_" + index, if the file name already exists). 

The files will be opened and processed using the following functions:
			processFiles(directory);
			analyzeImage();

This will be continued until all  specified .tif the selected folder and specified subfolders have been processed. 

author: Filip Liebsch, 2025

*/


//setup
run("Set Measurements...", "area mean min integrated decimal=4");
setOption("BlackBackground", true);
roiManager("UseNames", "true");

//program
chosenDir = getDirectory("chose a directory");
processFiles(chosenDir);
var size = 20958.3529;

//functions
//processFiles function screens folder and specified subfolders, creates directories, and opens .tif files with the specified names
function processFiles(directory) {

	fileList = getFileList(directory);

	outputDirName = directory + "Gphn_Analysis";//name of the newly created subfolder

	folderCount = 1;
	
	while (File.exists(outputDirName)) {
		print(outputDirName + " exists");
		outputDirName = directory + "Gphn_Analysis_" + folderCount; //when a subfolder from a previous analysis exists, a new folder with underscore and index will be created. 
		folderCount++;
	}
	
	outputDirPath = outputDirName + File.separator;

	folder = File.getName(directory);
	
	for (file = 0; file < fileList.length; file++) {
		if (endsWith(fileList[file], "gamma2Intensity.tif") && folder == "Masks_Intensities") { //Only specific subfolders will be analyzed, i.e. images in subfolders named "Mask_Intensities"
			File.makeDirectory(outputDirName);
			open(directory + fileList[file]);
			open(directory + "gamma2.tif");
			open(directory + "GphnIntensity.tif");
			open(directory + "Gphn.tif");
			open(directory + "Soma.tif");
			open(directory + "vGATIntensity.tif");
			open(directory + "vGAT.tif");
			open(directory + "Cell.tif");
			analyzeImage();	
			
		} else if (endsWith(fileList[file], "/") && !matches(fileList[file], ".*Gphn_Analysis_.*")) {
			processFiles(directory + fileList[file]);
		}
	}
}

/*
analyzeImage function will use the previously generated mScarlet-Gphn mask (mScarlet.tif) and with the imagej Analyze Particles algorithm, individual rois will be created.
The distance between the center of these ROIs (mScarlet-Gphn clusters) and the center of the soma will be measured.
Additionally, gamma2-, mScarlet-, and vGAT intensities in these ROIs will be measured (based on the background subtracted Average Z projections of the respective channels). 
Every individual ROI (mScarlet-Gphn) cluster will be classified as "negative" or "positive" for vGAT, gamma2, or Soma, based on their overlap with the respective masks. 

Date, Cell, and Condition will be read from folder and subfolder organization.

Data will be written in an organized "semi-tidy" table (one line per mScarlet-Gphn cluster). 

Results table, will be saved as .tsv file with the file name "ClusterAnalysis_"+ Name of the splice variant + number of the cell. 

The RoiManager will be saved as "RoiSetmScarletClusters.zip"
*/

function analyzeImage() {

	//Gphn clusters present ?
	selectWindow("Gphn.tif");
	run("Select None");
	run("Invert");
	run("Create Selection");
  	type = selectionType();
  	
  	if (type==-1){
     abort();
  	} else {
  	analysis();	
  	}
}


function analysis() {
	//coordinates of Soma Center
	selectWindow("Soma.tif");
	run("Invert");
	run("Create Selection");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "Soma");
	
	roiManager("Select", rois);
	centerSomaX = getValue("X"); //calibrated X value of the center of the Soma will be saved
	centerSomaY = getValue("Y"); //calibrated Y value of the center of the Soma will be saved
	selectWindow("Soma.tif");
	run("Select None");
	run("Invert");

    //size of cell
    selectWindow("Cell.tif");
    run("Invert");
    run("Create Selection");
    roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "Cell");
	roiManager("Select", rois);
	getStatistics(area, mean, min, max);
	size = area;
	selectWindow("Cell.tif");
	run("Select None");
	run("Invert");
    
	//individual Gphn mScarlet clusters
	selectWindow("Gphn.tif");
	run("Select None");
	run("Invert");
	run("Analyze Particles...", "size=0-Infinity exclude clear add");
	close("Gphn.tif");

	roiNumber = roiManager("count");
	run("Clear Results");	

	//analysis of individual ROIs
	for (m = 0; m < roiNumber; m++) {

	//intensity measurements
		//intensity of gamma2
		selectWindow("gamma2Intensity.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		setResult("MeanIntensitygamma2", m, mean);
		setResult("MaxIntensitygamma2", m, max);

		//intensity of mScarlet signal
		selectWindow("GphnIntensity.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		setResult("ClusterSize", m, area);
		setResult("MeanIntensityGphn", m, mean);
		setResult("MaxIntensityGphn", m, max);
		
		//intensity of vGAT signal
		selectWindow("vGATIntensity.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		setResult("MeanIntensityvGAT", m, mean);
		setResult("MaxIntensityvGAT", m, max);

	//classification of individual clusters
		//gamma2
		selectWindow("gamma2.tif");//
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		if (mean > 1) {
			setResult("gamma2", m, "positive");//
		} else {
			setResult("gamma2", m, "negative");//
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

		//Cell
		selectWindow("Cell.tif");
		roiManager("Select", m);
		getStatistics(area, mean, min, max);
		if (mean > 1) {
			setResult("InCell", m, "positive");
		} else {
			setResult("InCell", m, "negative");
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

		//global parameters
		setResult("CellSize", m, size);
		setResult("AllClusterNumber", m, roiNumber);

		//the last columns in the Results table will be filled with the date, condition and name of the cell
		setResult("Date", m, date);
		setResult("Condition", m, cond);
		setResult("Cell", m, cell);
		
	}
	
	saveAs("Results", outputDirPath+"ClusterAnalysis_"+ cond + cell + ".tsv");
	
	close("gamma2Intensity.tif");
	close("GphnIntensity.tif");
	close("vGATIntensity.tif");
	
	close("gamma2.tif");
	close("Soma.tif");
	close("vGAT.tif");
	close("Cell.tif");


	//save
	roiManager("Save", outputDirPath+"RoiSetClusters.zip");
	selectWindow("ROI Manager");
    run("Close");


}




function abort(){
    //size of cell
    selectWindow("Cell.tif");
    run("Invert");
    run("Create Selection");
    roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "Cell");
	roiManager("Select", rois);
	getStatistics(area, mean, min, max);
	size = area;
	selectWindow("Cell.tif");
	run("Select None");
	run("Invert");

	
	m = 0;
	run("Clear Results");

	mean = "NA";
	max = "NA";

	//intensity measurements
		//intensity of gamma2
		setResult("MeanIntensitygamma2", m, mean);
		setResult("MaxIntensitygamma2", m, max);

		//intensity of mScarlet signal
		setResult("ClusterSize", m, area);
		setResult("MeanIntensityGphn", m, mean);
		setResult("MaxIntensityGphn", m, max);
		
		//intensity of vGAT signal
		setResult("MeanIntensityvGAT", m, mean);
		setResult("MaxIntensityvGAT", m, max);

	//classification of individual clusters
		//gamma2
		setResult("gamma2", m, mean);//

		//vGAT
		setResult("vGAT", m, mean);

		//Soma
		setResult("Soma", m, mean);
	
		//Cell
		setResult("InCell", m, mean);

		//getting the names of the cell, condition, and date from the folder tree
		maskpath = File.getParent(directory); //in the parent of the directory (masks and intensities are saved here) Z-projections are saved
		cellpath = File.getParent(maskpath); //in the parent of the Z-projections .lif files are saved and the folder has the "name" of the cell
		cell = File.getName(cellpath); //the "name of the cell" will be saved in the variable cell 
		
		condpath = File.getParent(cellpath); //cells are saved in a folder that carries the "name" of the condition
		cond = File.getName(condpath); //the "name of the condition" will be saved in the variable cond 
		
		datepath = File.getParent(condpath); //conditions are saved in a folder that carries the date of the experiment
		date = File.getName(datepath); //the date will be saved in the variable date


		//distances
		setResult("DistanceCenter", m, mean);

		//global parameters
		setResult("CellSize", m, size);
		setResult("AllClusterNumber", m, 0);

		//the last columns in the Results table will be filled with the date, condition and name of the cell
		setResult("Date", m, date);
		setResult("Condition", m, cond);
		setResult("Cell", m, cell);
		
	
	saveAs("Results", outputDirPath+"ClusterAnalysis_"+ cond + cell + ".tsv");
	
	close("gamma2Intensity.tif");
	close("GphnIntensity.tif");
	close("vGATIntensity.tif");
	
	close("gamma2.tif");
	close("Soma.tif");
	close("vGAT.tif");
	close("Cell.tif");
	
	close("Gphn.tif");

	//save
	roiManager("Save", outputDirPath+"RoiSetClusters.zip");
	selectWindow("ROI Manager");
    run("Close");
	
}

























