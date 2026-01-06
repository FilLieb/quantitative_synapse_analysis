/*

This imagej Macro works with .tif files and is intended to be used subsequently to Macro: 1_FolderProcessor_LIF_Z-project.ijm

All folders and subfolders will be screened for MaxZ.tif and AvZ.tif files. 

If these files are detected, a subdirectory with the name "Masks_Intensities_" will be created (or "Masks_Intensities_" + index, if the file name already exists). 

The files will be opened and processed using the following functions:
			processFiles(directory);
			renaming();
			maskCell();
			maskSoma();
			maskvGAT();
			maskgamma2();
			maskMScarlet();

This will be continued until all MaxZ.tif and AvZ.tif files in the selected folder and subfolders have been processed. 

author: Filip Liebsch, 2025

*/

//setup
run("Set Measurements...", "area mean min integrated");
setOption("BlackBackground", true);

//program
chosenDir = getDirectory("chose a directory");
processFiles(chosenDir);

//functions
//processFiles function screens folder and subfolders, creates directories, and opens .tif files with the specified names MaxZ.tif & AvZ.tif
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
			renaming();
			maskCell();
			maskSoma();
			maskvGAT();
			maskgamma2();	
			maskMScarlet();
		} else if (endsWith(fileList[file], "/") && !matches(fileList[file], ".*Masks_Intensities.*")) {
			processFiles(directory + fileList[file]);
		}
	}
}

//renaming function splits MaxZ.tif & AvZ.tif into channels and renames images with the respective experimental condition
function renaming() { 
	
	//Split and rename channels
	selectWindow("MaxZ.tif");
	run("Split Channels");
	selectWindow("C1-MaxZ.tif");
	rename("CellMaxZ.tif");
	selectWindow("C2-MaxZ.tif");
	rename("mScarletGphnMaxZ.tif");
	selectWindow("C3-MaxZ.tif");
	rename("vGATMaxZ.tif");
	selectWindow("C4-MaxZ.tif");
	rename("gamma2MaxZ.tif");

	selectWindow("AvZ.tif");
	run("Split Channels");
	selectWindow("C1-AvZ.tif");
	rename("CellAvZ.tif");
	selectWindow("C2-AvZ.tif");
	rename("mScarletGphnAvZ.tif");
	selectWindow("C3-AvZ.tif");
	rename("vGATAvZ.tif");
	selectWindow("C4-AvZ.tif");
	rename("gamma2AvZ.tif");

	close("CellAvZ.tif");
	
}

//maskCell function filters, segments, and creates a Mask of the Cell. The mask will be saved as Cell.tif
function maskCell() { 
	//Soma mask
	selectWindow("CellMaxZ.tif");
	run("Median...", "radius=15");//10
	run("Duplicate...", "title=CellMask.tif");
	run("Enhance Contrast...", "saturated=0.1 normalize");	//0.1
	run("Auto Threshold", "method=Mean white");
	run("Options...", "iterations=4 count=1 black do=Dilate");
	run("Analyze Particles...", "size=350-Infinity show=Masks");
	rename("Cell.tif");
	save(outputDirPath + "Cell.tif");
	close("Cell.tif");
	close("CellMask.tif");

}



//maskSoma function filters, segments, and creates a Mask of the Soma. The mask will be saved as Soma.tif
function maskSoma() { 
	//Soma mask
	selectWindow("CellMaxZ.tif");
	rename("SomaMask.tif");
	run("Enhance Contrast...", "saturated=0.1 normalize");	//0.1
	run("Auto Threshold", "method=Otsu white");
	run("Options...", "iterations=4 count=1 black do=Dilate");
	run("Analyze Particles...", "size=25-Infinity show=Masks");
	rename("Soma.tif");
	save(outputDirPath + "Soma.tif");
	close("Soma.tif");
	close("SomaMask.tif");

}
/*
maskvGAT function filters, segments, and creates a Mask of vGAT clusters, the mask will be saved as vGAT.tif
Additionally, the background will be subtracted to obtain the fluorescence intensity of the vGAT channel (AverageZ projection). 
The image will be saved as vGATIntensity.tif
All vGAT images will be closed. 
*/

function maskvGAT() { 
	//vGAT mask
	selectWindow("vGATMaxZ.tif");
	rename("vGATMask.tif");
	run("Subtract Background...", "rolling=30");
	run("Auto Threshold", "method=Otsu white");
	run("Watershed");
	run("Analyze Particles...", "size=0.01-Infinity show=Masks");
	rename("vGAT.tif");
	
	save(outputDirPath + "vGAT.tif");
		
	//subtract background
	selectWindow("vGATAvZ.tif");
	rename("vGATIntensity.tif");
	run("Subtract Background...", "rolling=30");
	save(outputDirPath + "vGATIntensity.tif");

	close("vGATMask.tif");
	close("vGAT.tif");
	close("vGATIntensity.tif");
	
}

/*
maskgamma2 function filters, segments, and creates a Mask of gamma2 clusters, the mask will be saved as gamma2.tif
Additionally, the background will be subtracted to obtain the fluorescence intensity of the gamm2 channel (AverageZ projection). 
The image will be saved as gamma2Intensity.tif
All gamma2 images will be closed. 
*/


function maskgamma2() {
	//gamma2 mask
	selectWindow("gamma2MaxZ.tif");
	rename("gamma2Mask.tif");
	run("Subtract Background...", "rolling=30");
	run("Gaussian Blur...", "sigma=2");
	run("Auto Threshold", "method=Otsu white");
	run("Watershed");
	run("Analyze Particles...", "size=0.01-Infinity show=Masks");
	rename("gamma2.tif");
	
	save(outputDirPath + "gamma2.tif");
		
	//subtract background
	selectWindow("gamma2AvZ.tif");
	rename("gamma2Intensity.tif");
	run("Subtract Background...", "rolling=30");
	save(outputDirPath + "gamma2Intensity.tif");

	close("gamma2Mask.tif");
	close("gamma2.tif");
	close("gamma2Intensity.tif");

}

/*
maskMScarlet function filters, segments, and creates a Mask of mScarlet clusters, the mask will be saved as mScarlet.tif
Additionally, the background will be subtracted to obtain the fluorescence intensity of the mScarlet channel (AverageZ projection). 
The image will be saved as mScarletGphnIntensity.tif
All mScarlet images will be closed. 
*/

function maskMScarlet() {
	//Gphn filtering
	selectWindow("mScarletGphnMaxZ.tif");
	run("Duplicate...", "title=low.tif");
	selectWindow("mScarletGphnMaxZ.tif");
	run("Duplicate...", "title=high.tif");
	selectWindow("low.tif");
	run("Gaussian Blur...", "sigma=2");
	selectWindow("high.tif");
	run("Gaussian Blur...", "sigma=10");
	imageCalculator("Subtract", "low.tif","high.tif");
	selectWindow("low.tif");
	rename("GphnMask.tif");
	close("high.tif");
	close("mScarletGphnMaxZ.tif");
	
	//Gphn mask
	selectWindow("GphnMask.tif");
	run("Subtract Background...", "rolling=30");
	run("Auto Threshold", "method=Otsu white");
	run("Watershed");
	run("Analyze Particles...", "size=0.01-Infinity show=Masks");
	rename("Gphn.tif");

	save(outputDirPath + "Gphn.tif");
		
	//subtract background
	selectWindow("mScarletGphnAvZ.tif");
	rename("GphnIntensity.tif");
	run("Subtract Background...", "rolling=30");
	save(outputDirPath + "GphnIntensity.tif");

	close("GphnMask.tif");
	close("Gphn.tif");
	close("GphnIntensity.tif");

}

