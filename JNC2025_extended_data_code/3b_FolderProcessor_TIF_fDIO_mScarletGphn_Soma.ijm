/*

This imagej Macro works with .tif files and is intended to be used subsequently to Macro: 

1_FolderProcessor_LIF_Z-project.ijm
2_FolderProcessor_TIF_fDIO_Masks.ijm

All folders and specified subfolders (i.e. "Masks_Intensities_1") will be screened for gamma2Intensity.tif files. 

If these files are detected, a subdirectory with the name "mScarlet-Gphn_Analysis_" will be created (or "Gphn_Analysis_" + index, if the file name already exists). 

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
		if (endsWith(fileList[file], "gamma2Intensity.tif") && folder == "Masks_Intensities_1") { //Only specific subfolders will be analyzed, i.e. images in subfolders named "Mask_Intensities"
			File.makeDirectory(outputDirName);
			open(directory + fileList[file]);
			open(directory + "GphnIntensity.tif");
			open(directory + "Soma.tif");
			open(directory + "Cell.tif");
			analyzeImage();	
			
		} else if (endsWith(fileList[file], "/") && !matches(fileList[file], ".*Gphn_Analysis_.*")) {
			processFiles(directory + fileList[file]);
		}
	}
}

/*
analyzeImage function will use the previously generated Soma and Cell masks (Soma.tif/Cell.tif). 
Additionally, gamma2- and mScarlet- intensities in these ROIs will be measured (based on the background subtracted Average Z projections of the respective channels). 

Date, Cell, and Condition will be read from folder and subfolder organization.

Data will be written in an organized "semi-tidy" table (one line per cell). 

Results table, will be saved as .tsv file with the file name "Soma_Intensity_" + Name of the splice variant + number of the cell. 

The RoiManager will be saved as "RoiSetmScarletClusters.zip"
*/

function analyzeImage() {	
	//Soma to ROIManager
	selectWindow("Soma.tif");
	run("Invert");
	run("Create Selection");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "Soma");
	
    //Cell Soma to ROIManager
    selectWindow("Cell.tif");
    run("Invert");
    run("Create Selection");
    roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "Cell");
    
	run("Clear Results");	

	//intensity measurements
	//intensity of gamma2 Soma
	selectWindow("gamma2Intensity.tif");
	roiManager("Select", 0);
	getStatistics(area, mean, min, max);
	setResult("SomaMeanIntensitygamma2", 0, mean);
	setResult("SomaMaxIntensitygamma2", 0, max);

	//intensity of gamma2 Cell
	selectWindow("gamma2Intensity.tif");
	roiManager("Select", 1);
	getStatistics(area, mean, min, max);
	setResult("CellMeanIntensitygamma2", 0, mean);
	setResult("CellMaxIntensitygamma2", 0, max);

	//intensity of mScarlet signal Soma
	selectWindow("GphnIntensity.tif");
	roiManager("Select", 0);
	getStatistics(area, mean, min, max);
	setResult("SomaMeanIntensityGphn", 0, mean);
	setResult("SomaMaxIntensityGphn", 0, max);

	//intensity of mScarlet signal Cell
	selectWindow("GphnIntensity.tif");
	roiManager("Select", 1);
	getStatistics(area, mean, min, max);
	setResult("CellMeanIntensityGphn", 0, mean);
	setResult("CellMaxIntensityGphn", 0, max);
		

	//getting the names of the cell, condition, and date from the folder tree
	maskpath = File.getParent(directory); //in the parent of the directory (masks and intensities are saved here) Z-projections are saved
	cellpath = File.getParent(maskpath); //in the parent of the Z-projections .lif files are saved and the folder has the "name" of the cell
	cell = File.getName(cellpath); //the "name of the cell" will be saved in the variable cell 
		
	condpath = File.getParent(cellpath); //cells are saved in a folder that carries the "name" of the condition
	cond = File.getName(condpath); //the "name of the condition" will be saved in the variable cond 
		
	datepath = File.getParent(condpath); //conditions are saved in a folder that carries the date of the experiment
	date = File.getName(datepath); //the date will be saved in the variable date

	//the last columns in the Results table will be filled with the date, condition and name of the cell
	setResult("Date", 0, date);
	setResult("Condition", 0, cond);
	setResult("Cell", 0, cell);
	
	saveAs("Results", outputDirPath+"Soma_Intensity_"+ cond + cell + ".tsv");
	
	close("gamma2Intensity.tif");
	close("GphnIntensity.tif");
	
	close("Soma.tif");
	close("Cell.tif");


	//save
	roiManager("Save", outputDirPath+"RoiSetSoma.zip");
	selectWindow("ROI Manager");
    run("Close");


}

