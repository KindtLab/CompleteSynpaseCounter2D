// Functions:
//   built for generating neuromast masks
//   go though all czi 3D image stacks in the folder
//   provide Z-projection images for users to draw a single roi
//   save the binary mask of the roi
//
// Depends on plugin Masks From ROIs : https://sites.imagej.net/MasksfromRois/
// 20230517 Leiz


// **************************************************************
// **************************************************************

//  Set the channel config
    chArr =   newArray( "_maguk", "_ctbp", "_hc");
    chColor = newArray("Green", "Magenta", "Grays");
    chn = chArr.length;
    mskTog = 1; //1: toggle on NM mask drawing; 0: toggle off mask drawing
//***************************************************************    
//***************************************************************

inDir = getDirectory("--> INPUT: Choose Directory <--");
outDir = inDir;
outChPrj = outDir + File.separator + "chPrj" + File.separator;
outJpgs = outDir + File.separator + "chPrj" + File.separator + "Jpgs" + File.separator;

inList = getFileList(inDir);
list = getFromFileList("czi", inList);  // select dirs only
Array.sort(list);
nl = list.length;

// Checkpoint: get list of dirs
print("Below is a list of files to be processeded:");
printArray(list); // Implemented below
print("Result save to:");
print(outDir);
tag = "_hc_msk";

if (!File.exists(outChPrj)) {
    File.makeDirectory(outChPrj);
}
if (!File.exists(outJpgs)) {
    File.makeDirectory(outJpgs);
}
// data processing
setBatchMode(false);
roiManager("show none"); 
roiManager("reset"); 

for (i=0; i<nl; i++) { 
  curMskTog = mskTog;
  inFullname = inDir + list[i];
  sampleID = substring(list[i],0, lengthOf(list[i])-4);
  outFullname = outDir + sampleID + tag + ".tif";
//  txt = substring(list[i],0, lengthOf(list[i])-4);

  //status check
  statusCur = 0;
  for (j=1;j<chn+1;j++){
  	curPrj = outChPrj + sampleID + chArr[j-1] + "Prj.tif";
  	curJpg = outJpgs  + sampleID + chArr[j-1] + "Prj.jpg";
  	if(File.exists(curPrj)){
  		statusCur++;
  	}
  	}
  if (File.exists(outFullname)){curMskTog = 0;}
  print("Saving(",(i+1),"/",list.length,")...",list[i]); // Checkpoint: Indicating progress
  
  if (statusCur<chn || curMskTog){
  open(inFullname);
  rename("Current");
  run("Duplicate...", "title=Current1 duplicate");
  run("Split Channels");
  for (j=1;j<chn+1;j++){
  	curPrj = outChPrj + sampleID + chArr[j-1] + "Prj.tif";
  	curJpg = outJpgs  + sampleID + chArr[j-1] + "Prj.jpg";
  	selectWindow("C" + j + "-Current1");
    run("Subtract Background...", "rolling=50 stack");
    selectWindow("C" + j + "-Current1");
    run("Z Project...", "projection=[Max Intensity]");
    if(!File.exists(curPrj)){
    saveAs("Tiff", curPrj );
    saveAs("Jpg", curJpg);
    }
    selectWindow("C" + j + "-Current1"); close();
  }	
  
  if (curMskTog){
  selectWindow("Current");	
  run("Z Project...", "projection=[Max Intensity]");
  rename("zpj");
  selectWindow("zpj");
  Stack.setDisplayMode("composite");
  //  Stack.setActiveChannels("110");
//  run("8-bit");
  for (j=1;j<chn+1;j++){
  Stack.setChannel(j)
  run("Enhance Contrast", "saturated=0.02");
  run(chColor[j-1]);
  }
  run("Flatten");
     
  // Prompt the user to draw an ROI
  run("ROI Manager...");
  roiManager("reset");
  run("Show All");
  selectWindow("zpj-1");	
  waitForUser("Draw ROI, then hit OK");   
  roiManager("Add");
    
  run("Binary (0-255) mask(s) from Roi(s)", "show_mask(s) save_in=[] suffix=[] save_mask_as=tif rm=[RoiManager[size=1, visible=true]]");
  saveAs("Tiff", outFullname);
  roiManager("reset");
  run("Close All");
  print("...done.");
  }
  }else{
  	print("...skipped");//Checkpoint: Done one.
  }
}

setBatchMode("exit and display");
print("--- All Done ---");

// --- Main procedure end ---

////
function getFromFileList(ext, fileList)
{
  // Select from fileList array the filenames with specified extension
  // and return a new array containing only the selected ones.
  selectedFileList = newArray(fileList.length);
  selectedDirList = newArray(fileList.length);
  ext = toLowerCase(ext);
  j = 0;
  iDir = 0;
  for (i=0; i<fileList.length; i++)
    {
      extHere = toLowerCase(getExtension(fileList[i]));
      if (endsWith(fileList[i], "/"))
        {
      	  selectedDirList[iDir] = fileList[i];
      	  iDir++;
        }
      else if (extHere == ext)
        {
          selectedFileList[j] = fileList[i];
          j++;
        }
    }
    
  selectedFileList = Array.trim(selectedFileList, j);
  selectedDirList = Array.trim(selectedDirList, iDir);
  if (ext == "")
    {
    	return selectedDirList;
    }
  else 
    {
    	return selectedFileList;
    }
}

/////
function printArray(array)
{ 
  // Print array elements recursively 
  for (i=0; i<array.length; i++)
    print(array[i]);
}

////
function getExtension(filename)
{
  ext = substring( filename, lastIndexOf(filename, ".") + 1 );
  return ext;
}