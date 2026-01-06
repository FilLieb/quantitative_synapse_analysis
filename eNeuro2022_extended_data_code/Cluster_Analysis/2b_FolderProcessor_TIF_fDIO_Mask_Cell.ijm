/*

This imagej Macro works with .tif files and is intended to be used subsequently to Macro: 1_FolderProcessor_LIF_Z-projections.ijm

All folders and subfolders will be screened for MaxZ.tif files. 

The files will be opened and processed using the following functions:
			processFiles(directory);
			renaming();
			maskCell();

This will be continued until all MaxZ.tif files in the selected folder and subfolders have been processed. 

author: Filip Liebsch, 2022

*/






//setup
run("Set Measurements...", "area mean min integrated");
setOption("BlackBackground", true);

//program
chosenDir = getDirectory("chose a directory");
processFiles(chosenDir);

//functions
//processFiles function screens folder and subfolders, creates directories, and opens .tif files with the specified name MaxZ.tif
function processFiles(directory) {

	fileList = getFileList(directory);

	outputDirName = directory + "Masks_Intensities_1";//this is the pre-existing output directory, image will be saved in this folder
	
	outputDirPath = outputDirName + File.separator;
	
	for (file = 0; file < fileList.length; file++) {
		if (endsWith(fileList[file], "MaxZ.tif")) {
			open(directory + fileList[file]);
			renaming();
			maskCell();
		} else if (endsWith(fileList[file], "/") && !matches(fileList[file], ".*Masks_Intensities.*")) {
			processFiles(directory + fileList[file]);
		}
	}
}

//renaming function splits MaxZ.tif into channels and renames images C1-... with CellMaxZ.tif
function renaming() { 
	
	//Split and rename channels
	selectWindow("MaxZ.tif");
	run("Split Channels");
	selectWindow("C1-MaxZ.tif");
	rename("CellMaxZ.tif");
	
	close("C2-MaxZ.tif");
	close("C3-MaxZ.tif");
	close("C4-MaxZ.tif");
	close("MaxZ.tif");

}

//maskCell function filters, segments, and creates a Mask of the Cell. The mask will be saved as Cell.tif
function maskCell() { 
	//Soma mask
	selectWindow("CellMaxZ.tif");
	run("Median...", "radius=15");//10
	run("Enhance Contrast...", "saturated=0.1 normalize");	//0.1
	run("Subtract...", "value=2000");
	run("Auto Threshold", "method=Mean white");
	run("Analyze Particles...", "size=250-Infinity show=Masks");
	rename("Cell.tif");
	save(outputDirPath + "Cell.tif");
	close("Cell.tif");
	close("CellMaxZ.tif");

}


