/*

This imagej Macro works with .tif files and is intended to be used subsequently to Macro: 1_FolderProcessor_LIF_Z-projections.ijm

All folders and subfolders will be screened for MaxZ.tif and AvZ.tif files. 

If these files are detected, a subdirectory with the name "Masks_Intensities_" will be created (or "Masks_Intensities_" + index, if the file name already exists). 

The files will be opened and processed using the following functions:
			processFiles(directory);
			renaming();
			maskSoma();
			maskvGAT();
			maskMScarlet();
			maskMEGFP();	

This will be continued until all MaxZ.tif and AvZ.tif files in the selected folder and subfolders have been processed. 

author: Filip Liebsch, 2022

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
			maskSoma();
			maskvGAT();
			maskMScarlet();
			maskMEGFP();	
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
	rename("EGFPGphnMaxZ.tif");
	selectWindow("C3-MaxZ.tif");
	rename("mScarletGphnMaxZ.tif");
	selectWindow("C4-MaxZ.tif");
	rename("vGATMaxZ.tif");

	selectWindow("AvZ.tif");
	run("Split Channels");
	selectWindow("C1-AvZ.tif");
	rename("CellAvZ.tif");
	selectWindow("C2-AvZ.tif");
	rename("EGFPGphnAvZ.tif");
	selectWindow("C3-AvZ.tif");
	rename("mScarletGphnAvZ.tif");
	selectWindow("C4-AvZ.tif");
	rename("vGATAvZ.tif");

	close("CellAvZ.tif");
	
}

//maskSoma function filters, segments, and creates a Mask of the Soma and adds it to the roiManager, the mask will be saved as Soma.tif
function maskSoma() { 
	//Soma mask
	selectWindow("CellMaxZ.tif");
	rename("SomaMask.tif");
	run("Median...", "radius=10");
	run("Enhance Contrast...", "saturated=0.5 normalize");
	run("Auto Threshold", "method=Otsu white");
	run("Options...", "iterations=4 count=1 black do=Dilate");
	run("Analyze Particles...", "size=25-Infinity show=Masks exclude add");
	rename("Soma.tif");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "Soma");
	run("Select None");	
	roiManager("Show All without labels");
	roiManager("Show None");
	save(outputDirPath + "Soma.tif");
	close("Soma.tif");
	close("SomaMask.tif");

}
/*
maskvGAT function filters, segments, and creates a Mask of vGAT clusters and adds them to the roiManager, the mask will be saved as vGAT.tif

Additionally, the background will be subtracted to obtain the fluorescence intensity of the vGAT channel (AverageZ projection). 
The background fluorescence will be measured outside vGAT clusters and subsequently subtracted from the raw vGAT AverageZ projection.
The image will be saved as vGATIntensity.tif
All vGAT images will be closed. 
*/

function maskvGAT() { 
	//vGAT mask
	selectWindow("vGATMaxZ.tif");
	rename("vGATMask.tif");
	run("Subtract Background...", "rolling=30");
	run("Auto Threshold", "method=Default white");
	run("Watershed");
	run("Analyze Particles...", "size=0-Infinity show=Masks");
	rename("vGAT.tif");
	run("Create Selection");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "vGAT");	
	roiManager("Select", "vGAT");
	run("Make Inverse");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "vGAT_bckgrd");
	run("Select None");
	roiManager("Show All without labels");
	roiManager("Show None");	
	save(outputDirPath + "vGAT.tif");
		
	//subtract background
	selectWindow("vGATAvZ.tif");
	rename("vGATIntensity.tif");
	roiManager("Select", "vGAT_bckgrd");
	bckgrd_vGAT = getValue("Mean");
	run("Select None");
	run("Subtract...", "value=" + bckgrd_vGAT);
	save(outputDirPath + "vGATIntensity.tif");

	close("vGATMask.tif");
	close("vGAT.tif");
	close("vGATIntensity.tif");
	
}

/*
maskMScarlet function filters, segments, and creates a Mask of mScarlet clusters and adds them to the roiManager, the mask will be saved as mScarlet.tif
To account for variable Gphn expression per cell, the average fluorescence intensity of diffusely distributed Gphn (outside clusters) in the neuronal soma will be measured.
This value will be used to calculate the "prominence" used in the imagej Find Maxima... algorithm. 

Additionally, the background will be subtracted to obtain the fluorescence intensity of the mScarlet channel (AverageZ projection). 
The background fluorescence will be measured outside mScarlet clusters and subsequently subtracted from the raw mScarlet AverageZ projection.
The image will be saved as mScarletGphnIntensity.tif
All mScarlet images will be closed. 
*/

function maskMScarlet() { 
	selectWindow("mScarletGphnMaxZ.tif");
	prom_mSc = (getValue("Max")/4);
	rename("mScarletGphnMask.tif");
	run("Subtract Background...", "rolling=50");
	
	//mScarlet Gphn Soma mask
	run("Duplicate...", " ");
	rename("GphnMaskSoma.tif");
	roiManager("Select", "Soma");
	run("Find Maxima...", "prominence=" + prom_mSc + " strict output=[Maxima Within Tolerance]");
	rename("SomClus.tif");
	run("Create Selection");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "SomClus");
	roiManager("Select", newArray(0,3));
	roiManager("XOR");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "mScdiffSom");
	close("SomClus.tif");
	close("GphnMaskSoma.tif");

	//mScarlet Gphn mask
	selectWindow("mScarletGphnMask.tif");
	roiManager("Select", "mScdiffSom");
	mScSomGeph = getValue("Mean");
	prommSc = (mScSomGeph*4);
	run("Select None");
	run("Subtract...", "value=" + mScSomGeph);
	run("Find Maxima...", "prominence=" + prommSc + " strict output=[Maxima Within Tolerance]");
	rename("mScarletMax.tif");
	run("Watershed");
	run("Analyze Particles...", "size=0-Infinity show=Masks");
	rename("mScarlet.tif");
	run("Create Selection");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "mScarletGphn");	
	roiManager("Select", "mScarletGphn");
	run("Make Inverse");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "mScarletGphn_bckgrd");

	run("Select None");
	roiManager("Show All without labels");
	roiManager("Show None");
	save(outputDirPath + "mScarlet.tif");

	//subtract background
	selectWindow("mScarletGphnAvZ.tif");
	rename("mScarletGphnIntensity.tif");
	roiManager("Select", "mScarletGphn_bckgrd");
	bckgrd_gphn = getValue("Mean");
	run("Select None");
	run("Subtract...", "value=" + bckgrd_gphn);
	save(outputDirPath + "mScarletGphnIntensity.tif");

	close("mScarletGphnMask.tif");
	close("mScarlet.tif");
	close("mScarletGphnIntensity.tif");
	close("mScarletMax.tif");

}

/*
maskMEGFP function filters, segments, and creates a Mask of mEGFP clusters and adds them to the roiManager, the mask will be saved as mEGFP.tif
To account for variable Gphn expression per cell, the average fluorescence intensity of diffusely distributed Gphn (outside clusters) in the neuronal soma will be measured.
This value will be used to calculate the "prominence" used in the imagej Find Maxima... algorithm. 

Additionally, the background will be subtracted to obtain the fluorescence intensity of the mEGFP channel (AverageZ projection). 
The background fluorescence will be measured outside mEGFP clusters and subsequently subtracted from the raw mEGFP AverageZ projection.
The image will be saved as mEGFPGphnIntensity.tif
All mEGFP images will be closed. 

The roiManager will be saved as Masks.zip and closed. 
*/

function maskMEGFP() {
	selectWindow("EGFPGphnMaxZ.tif");
	promm_EGFP = (getValue("Max")/4);
	rename("mEGFPGphnMask.tif");
	run("Subtract Background...", "rolling=50");
	
	//mEGFP Gphn Soma mask
	run("Duplicate...", " ");
	rename("GphnMaskSoma.tif");
	roiManager("Select", "Soma");
	run("Find Maxima...", "prominence=" + promm_EGFP + " strict output=[Maxima Within Tolerance]");
	rename("SomClus.tif");
	run("Create Selection");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "GFPSomClus");
	roiManager("Select", newArray(0,7));
	roiManager("XOR");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "mEGFPdiffSom");
	close("SomClus.tif");
	close("GphnMaskSoma.tif");

	//mEGFP Gphn mask
	selectWindow("mEGFPGphnMask.tif");
	roiManager("Select", "mEGFPdiffSom");
	mEGFPSomGeph = getValue("Mean");
	prommEGFP = (mEGFPSomGeph*4);
	run("Select None");
	run("Subtract...", "value=" + mEGFPSomGeph);
	run("Find Maxima...", "prominence=" + prommEGFP + " strict output=[Maxima Within Tolerance]");
	rename("mEGFPMax.tif");
	run("Watershed");
	run("Analyze Particles...", "size=0-Infinity show=Masks");
	run("Create Selection");
	roiManager("Add");
	rename("mEGFP.tif");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "mEGFPGphn");	
	roiManager("Select", "mEGFPGphn");
	run("Make Inverse");
	roiManager("Add");
	rois = roiManager("count") - 1;
	roiManager("Select", rois);
	roiManager("Rename", "mEGFPGphn_bckgrd");
	run("Select None");
	roiManager("Show All without labels");
	roiManager("Show None");
	save(outputDirPath + "mEGFP.tif");

	//subtract background
	selectWindow("EGFPGphnAvZ.tif");
	rename("mEGFPGphnIntensity.tif");
	roiManager("Select", "mEGFPGphn_bckgrd");
	bckgrd_gphn = getValue("Mean");
	run("Select None");
	run("Subtract...", "value=" + bckgrd_gphn);
	save(outputDirPath + "mEGFPGphnIntensity.tif");	

	close("mEGFPGphnMask.tif");
	close("mEGFPGphnIntensity.tif");
	close("mEGFP.tif");
	close("mEGFPMax.tif");

	roiManager("Save", outputDirPath + "Masks.zip");
	selectWindow("ROI Manager");
    run("Close");

}

