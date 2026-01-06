/*

This imagej Macro works with .tif files and is intended to be used subsequently to Macro: 

1_FolderProcessor_LIF_Z-projections.ijm
2b_FolderProcessor_TIF_fDIO_Mask_Cell.ijm

All folders and specified subfolders (i.e. "Masks_Intensities_1") will be screened for Cell.tif files. 

If these files are detected, a subdirectory with the name "number_of_clusters" will be created (or "number_of_clusters_" + index, if the file name already exists). 

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

	outputDirName = directory + "number_of_clusters";//name of the newly created subfolder

	folderCount = 1;
	
	while (File.exists(outputDirName)) {
		print(outputDirName + " exists");
		outputDirName = directory + "number_of_clusters_" + folderCount; //when a subfolder from a previous analysis exists, a new folder with underscore and index will be created. 
		folderCount++;
	}
	
	outputDirPath = outputDirName + File.separator;

	folder = File.getName(directory);
	
	for (file = 0; file < fileList.length; file++) {
		if (endsWith(fileList[file], "Cell.tif") && folder == "Masks_Intensities_1") { //Only specific subfolders will be analyzed, i.e. images in subfolders named "Mask_Intensities_1"
			File.makeDirectory(outputDirName);
			open(directory + fileList[file]);
			open(directory + "mScarlet.tif");
			open(directory + "gamma2.tif");
			open(directory + "vGAT.tif");
			analyzeImage();	
			
		} else if (endsWith(fileList[file], "/") && !matches(fileList[file], ".*number_of_clusters_.*")) {
			processFiles(directory + fileList[file]);
		}
	}
}

/*
analyzeImage function will use the previously generated cell mask (Cell.tif) and with the imagej Analyze Particles algorithm, individual rois will be created.
If multiple ROIs are detected only the largest ROI will be used for analysis. The size of this ROI will be saved. 

Individual mScarlet Gphn clusters inside this largest ROI will be saved in individual ROIs with the imagej Analyze Particles algorithm.
These individual ROIs will be classified as vGAT or gamma2, "negative" or "positive". 

Date, Cell, and Condition will be read from folder and subfolder organization.

Data will be written in an organized "semi-tidy" table (one line per cluster). 

Results table, will be saved as .tsv file with the file name "ClusterNumber_"+ Name of the splice variant + number of the cell. 

*/

function analyzeImage() {	
	//Cell
	selectWindow("Cell.tif");
	run("Invert");
	run("Select None");
	run("Analyze Particles...", "size=0-Infinity clear add");

	cells = roiManager("count");
	size = newArray(cells);
	for (i=0; i<cells; i++) {
		roiManager("select", i);
		size[i] = getValue("Area");
	}
	//ROIs will be ranked according to size
	ranks = Array.rankPositions(size);

	for (i=0; i<cells; i++) {
		roiManager("select", i);
		roiManager("Rename", IJ.pad(ranks[i]+1, 4)); 
	}
	run("Select None");
	roiManager("Sort");

	//size of the largest ROI will be saved in the variable "cell_size"
	roiManager("Select", cells-1);
	roiManager("Rename", "Cell");
	roiManager("Select", cells-1);
	cell_size = getValue("Area");

	//individual Gphn mScarlet clusters inside the largest cell ROI
	selectWindow("mScarlet.tif");
	roiManager("Select", cells-1);
	run("Clear Outside");
	run("Select None");
	run("Invert");
	run("Analyze Particles...", "size=0-Infinity clear add");
	close("mScarlet.tif");
	
	roiNumber = roiManager("count");
	run("Clear Results");	

for (m = 0; m < roiNumber; m++) {
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
		
		//getting the names of the cell, condition, and date from the folder tree
		maskpath = File.getParent(directory); //in the parent of the directory (masks and intensities are saved here) Z-projections are saved
		cellpath = File.getParent(maskpath); //in the parent of the Z-projections .lif files are saved and the folder has the "name" of the cell
		cell = File.getName(cellpath); //the "name of the cell" will be saved in the variable cell 
		
		condpath = File.getParent(cellpath); //cells are saved in a folder that carries the "name" of the condition
		cond = File.getName(condpath); //the "name of the condition" will be saved in the variable cond 
		
		datepath = File.getParent(condpath); //conditions are saved in a folder that carries the date of the experiment
		date = File.getName(datepath); //the date will be saved in the variable date


		setResult("Clusters", m, roiNumber);
		setResult("CellArea", m, cell_size);

		//the last columns in the Results table will be filled with the date, condition and name of the cell
		setResult("Date", m, date);
		setResult("Condition", m, cond);
		setResult("Cell", m, cell);
		
	}

	//save
	saveAs("Results", outputDirPath+"ClusterNumber_"+ cond + cell + ".tsv");
	
	close("Cell.tif");
	close("gamma2.tif");
	close("vGAT.tif");
	selectWindow("ROI Manager");
    run("Close");

}

