//            ********************************************************
//            ** Neuromast_CompleteSynaspseCounter2D 5.3a, Kindt Lab **
//            ********************************************************

// Tested on ICaveJ 1.54f, Fiji
// plugins required: AdaptiveThreshold (https://sites.imagej.net/adaptiveThreshold/)
// adopted from Candy Wong 2013 Jan.
// 2023 Mar. 24 by Zhengchang Lei

//--------------------------------------------------------------------------------------
//--- update log

// 20230328 Leiz
// save data of all samples in master lists: NMstats, Target stats  
// enlarge rbb or cav rois for paired pre-sysnapse or post-synapse counting
// use HC mask to exclude signals outside of NM, 
//    if there's no mask file for a image file, the whole field of view is included. 

// 20230329 Leiz
// contrast adjust before thresholding is important for accurate counting.

// 20230421 Leiz
// critical: remove the stack Normalizer for intensity quantification.
// version 3.0

// 20230505 Leiz
// optional: rbb channel for more precious size measurement, use outside NM region to get
//     background info.
// version 5.0

// 20230508 Leiz
// added average size to NM stats 

// 20230517 Leiz
// set measurement before the image processing
// adapt MAC osx file path

// 20230601 Leiz
// Load z-project image if it's previously saved. Save z-prj images if its not.
// no Background thresholding module
// optional: save zoomed jpg files.
// re-frame the flow
// version 5.1

// 20230706 Leiz
// added the section to load and Z-project tif file for segmented channels
// auto determine the name of the adaptive thresholding plugin 
// added the option to manually try adaptive thresholding and determing the parameters
// adaptive thresholding parameters for each sample are saved int he NM stats table

// 20230810 Leiz
// added an enhanced watershed opiton for circular/round particals:
//   fingding local maximal on the local thresholded gray-scale image + watershed in 3Dsuite
// version 5.2

// 20231012 Leiz
// move circularity check to before watershed in the partical analysis for maguk.

//20250227 Leiz
//simplify the function for two targets, universal adaptive parameters

//20252318 Leiz
//remove background particle counting, manual adpThr, enhanced watersheding entry from 5.3a version







// ####################################################################################################################
// Initiation section


// Parameter Settings************************************************************************ 
  // ----------------------------------------------------------------------------------------
  //  !!! Z-prj of channels should be named as: sampleNames + chsSuffix + Prj.tif 
  //  !!! Segmentation of channels should be named as: sampleNames + chsSuffix + Seg.tif
  // ----------------------------------------------------------------------------------------
  // in the sequence of channels:
  chsSuffix = newArray( "_mag",  "_ctbp","_hc"); //tag of singal channel Z-prj
  tgColor = newArray("Green",  "Red","Grays"); //
  chHairCell = 3; // HC channel position

  // Counting configurations:
  tgn = 2; // number of counting targets
  cntTgt = newArray(  "ctbp",    "mag"); // counting targets
  pairTgt = newArray(  "mag",   "ctbp"); // pairing target
  tgChPos = newArray(        2,        1); // target channel position
  apSizeMin=newArray(    0.025,     0.04); // 2D size threshold for "Analyze Particle", 
  athrBlockSize=newArray(   60,      110); // adaptive thresholding block size,
  athrBG = newArray(       -35,      -35); // adaptive thresholding backgroud, 
 //******************************************************************************************

  prDis = 2; //pairing distance (by pixes)
  chN = chsSuffix.length; // number of channels 
  suffix_for_HCmsk = "_hc_msk"; //if there's a mask, name it as ImageName + suffix_for_HCmsk
  //Stats table headers
  NMheaders = newArray("SampleID", 
              cntTgt[0]+"Paired",cntTgt[0]+"#", cntTgt[0]+"Up", cntTgt[0]+"AvgSize", cntTgt[0]+"adpBlockSize", cntTgt[0] +"adpBG",  
              cntTgt[1]+"Paired",cntTgt[1]+"#", cntTgt[1]+"Up", cntTgt[1]+"AvgSize", cntTgt[1]+"adpBlockSize", cntTgt[1] +"adpBG");
  pmn = NMheaders.length;
  
  // adaptive thresholding plugin named differently in OSX and Windows
  if (File.separator == "/"){
  adpThrPlugin = "adaptiveThr ";
  }else{
  	adpThrPlugin = "adaptiveThr Plugin";
  }
//That's all!

// select input folder
inDir = getDirectory("--> INPUT: Choose Directory <--");
outDir = getDirectory("--> OUTPUT: Choose Directory for TIFF Output <--");

// bulid output folders
outXlsx = outDir +  "xlsx" + File.separator;
if (!File.exists(outXlsx)) {
    File.makeDirectory(outXlsx);
}
outRoi = outDir +  "Rois" + File.separator;
if (!File.exists(outRoi)) {
    File.makeDirectory(outRoi);
}
outJPG = outDir +  "Jpgs" + File.separator;
if (!File.exists(outJPG)) {
    File.makeDirectory(outJPG);
}
inZprj = inDir +  "chPrj" + File.separator;
if (!File.exists(inZprj)) {
    File.makeDirectory(inZprj);
}
dataSet = File.getName(inDir);
paraFile = outDir + dataSet + "_counting parameters.txt";
masterFileNM = outDir + dataSet + "_MasterFile_NMstats.csv";
masterFileTg1 = outDir + dataSet + "_MasterFile_" + cntTgt[0] + ".csv";
masterFileTg2 = outDir + dataSet + "_MasterFile_" + cntTgt[1] + ".csv";
      directory_tiff = outDir;
      directory_jpg = outDir;
      directory_spreadsheet = outDir;
      directory_roi = outDir;
inList = getFileList(inDir);
list = getFromFileList("czi", inList);  // select dirs only
Array.sort(list);
fn = list.length;
  jpgZoom = 2; //zoom factor for saved jpg
  bgThrTog = newArray(       0,        0); // target channel tog for background size&int thresholding
  bgThrUL = newArray(     0.06,      0.1); // maximum size for background particals
  manualAdp = newArray(      0,        0); // option to manually determin adaptive thresholding parameters for each sample 1: interactive, 2: pre-determined
//  circularMin = newArray(  0.1,      0.1); // 2D circularity threshold for "Analyze Particle", /curCir
//  tgContrast = newArray(  0.01,     0.01); // target channel contrast /curContrast
//  enWatershed = newArray(    0,        0);
//  enWed_radius = newArray(   3,        0);

// Checkpoint: get list of dirs
print("Below is a list of files to be processeded:");
printArray(list); // Implemented below
print("Result save to:");
print(outDir);

chcon=chsSuffix[0]; //build channel names in a string
for (icc=1;icc<chN;icc++){
	chcon = chcon + ";" + chsSuffix[icc];
}
print(chcon);
// save parameter to txt file
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
f = File.open(paraFile);
print(f, "Parameters used as follow: ( " + year +"-"+ month+"-" + dayOfMonth +"_"+ hour+"-"+ minute+"-"+ second + ")");
print(f, "channel config = " + chcon);
print(f, "Counting configs:");
print(f, "Counting targets = " + cntTgt[0] + ";" + cntTgt[1]);
print(f, "AnalyzeParticles sizeMin = " + apSizeMin[0] + ";" + apSizeMin[1]);
//print(f, "AnalyzeParticles circularityMin = " + circularMin[0] + ";" + circularMin[1]);
print(f, "AdaptiveTHR blockSize = " + athrBlockSize[0] + ";" + athrBlockSize[1]);
print(f, "AdaptiveTHR background = " + athrBG[0] + ";" + athrBG[1] );
print(f, "prDis = " + prDis);

File.close(f);

//###################################################################################
// --- Main Processing starts here ---

roiManager("show none"); // to avoid a weird error of the ROImanager reset function
run("Set Measurements...", "area mean centroid shape integrated add redirect=None decimal=3");
setBatchMode(true);
//setBatchMode(false);

SampleNames = newArray(fn);

Table.create("NMstats");
Table.update("NMstats");
 for (it = 0;it<pmn; it++){
 	Table.setColumn(NMheaders[it]);
 }
 Table.update(); 

Table.create(cntTgt[0] + "Stats");
Table.update(cntTgt[0] + "Stats");
Table.create(cntTgt[1] + "Stats");
Table.update(cntTgt[1] + "Stats");

//xxxxxxxxxxxxxxxxxxxxxxxxxxx The Processing Loop xxxxxxxxxxxxxxxxxxxxxxxxx
for (i=0; i<fn; i++){     
  spName = 	substring(list[i],0, lengthOf(list[i])-4);
  SampleNames[i] = spName;
     selectWindow("NMstats");
     Table.set("SampleID", i, spName);
     Table.update();
  manualMask = 0;
  inFullname = inDir + list[i];
  inFullnameHCmsk = inDir + spName + suffix_for_HCmsk + ".tif";
  
  inFullnamePrjs = newArray();
  inFullnameSegs = newArray();
  for (ich=0;ich<chN;ich++){ 
  inFullnamePrjs[ich] = inZprj + spName + chsSuffix[ich] + "Prj.tif";
  inFullnameSegs[ich] = inDir + spName + chsSuffix[ich] + "Seg.tif";
  }
  
  FN_2Droi = newArray();
  FN_BG = newArray();
  FN_count = newArray();
  FN_Seg2D = newArray();
  FN_CountBG = newArray();
  FN_area = newArray();
  for(itg = 0;itg<tgn; itg++){
    FN_2Droi[itg] = spName + "_" + cntTgt[itg] + "2Droi.zip";                   
    FN_BG[itg] = spName + "_BG" + cntTgt[itg] + ".jpeg";                        
    FN_count[itg] = spName + "_" + cntTgt[itg] + "Count.csv";                        
    FN_area[itg] = spName + "_" + cntTgt[itg] + "Area_thr-";    
    FN_Seg2D[itg] = spName  + "_Seg" + cntTgt[itg] + ".jpeg";    
    FN_CountBG[itg] = spName + "_" + cntTgt[itg] + "CountBG.csv";
  }
                            
    
    FN_manualAdp = spName + "_manualAdp.txt"; 
//    FN_EXroi = spName + "_EXroi.zip";
    Seg2D_tif =   spName  + "_Seg2D.tif";
    Seg2D_jpeg = spName  + "_Seg2D.jpeg";
    Seg2D_hc =  spName  + "_hc.jpeg";
    msk_jpeg =  spName  + "_msk.jpeg";
    msk_tif =  spName  + "_msk.tif";
    
      outFullname_ZP = outDir + substring(list[i],0, lengthOf(list[i])-4) + ".png";
      // Checkpoint: Indicating progress
      print("Processing(",(i+1),"/",list.length,")...",list[i]); 
    
//**********loading images, save Z-prj if it's not generated beforehand. **************
    for (ich=1;ich<chN+1;ich++){
    	// load projection tif if exist
      if (File.exists(inFullnamePrjs[ich-1])) {
      	open(inFullnamePrjs[ich-1]); rename("C" + ich +"-Current");
//      	print(inFullnamePrjs[ich-1]);
      }else{
      	    // projection from segmented channels
	    	if (!isOpen("CurrentStack")){
	    		print(inFullname);
		      	open(inFullname); rename("CurrentStack");
		      	getPixelSize(unit, px, py, pz);
		    }
		    // sync segment stack pixel sizes with the original stack
	      	if (File.exists(inFullnameSegs[ich-1])){
	      		open(inFullnameSegs[ich-1]); rename("CurrentStack-1");
	      		run("Properties...", "unit=micron pixel_width=px pixel_height=py voxel_depth=pz");
	      	}else{
	      		// projection from original stack
		      	selectWindow("CurrentStack");
		      	run("Duplicate...", "duplicate channels=" + ich);
		    }
		    // projectn and save in tif 
	      	selectWindow("CurrentStack-1");
	        run("Subtract Background...", "rolling=50 stack");
	        run("Z Project...", "projection=[Max Intensity]");
	        saveAs("tif",inFullnamePrjs[ich-1]);
	        rename("C" + ich +"-Current");
	        selectWindow("CurrentStack-1");close();
      }
    }
    
    if (isOpen("CurrentStack")){
    	selectWindow("CurrentStack");close();
    }
    
    // recogonize the hair cell channel
     selectWindow("C" + chHairCell + "-Current");
     rename("hc");
    
    // load hair cell mask
    if (!isOpen("HCmsk")){
	    if (File.exists(inFullnameHCmsk)){
	    	open(inFullnameHCmsk);
	    	manualMask = 1;
	    	rename("HCmsk");
	    }else{
	         bgThrTog = newArray(0,0,0);
	         selectWindow("hc");
	         run("Duplicate...", "title=HCmsk");
	         run("Add...", "value=100");
             setMinAndMax(0, 1);
             run("8-bit");
             //run("Divide...", "value=255");
	    }
   }
    // generate background mask 
    selectWindow ("HCmsk");
	  	run("Duplicate...", "title=BG");
	    run("Invert");
	    run("Divide...", "value=255");
    selectWindow ("HCmsk");
    	run("Divide...", "value=255");
    
//*********** puncta counting *******************************  
    // generate masks for target channels
    for (itg = 0;itg<tgn;itg++){
         curCh = tgChPos[itg];
         curTgt = cntTgt[itg];
         curBlockSize = athrBlockSize[itg];
         curBG = athrBG[itg];

         curContrast = 0.01;
         curApSizeMin = apSizeMin[itg];
         curCir = 0.1;
         selectWindow("C" + curCh + "-Current");
         rename(curTgt);
         imageCalculator("Multiply create", curTgt, "HCmsk");
         rename(curTgt + "_m");
         resetMinAndMax();
         run("Apply LUT");
         run("8-bit");
         selectWindow("NMstats");
         Table.set(cntTgt[itg]+"adpBlockSize",i, curBlockSize);
	     Table.set(cntTgt[itg]+"adpBG",i, curBG); 
	     Table.update();
	     
	     selectWindow(curTgt + "_m");
         run("adaptiveThr ", "using=[Weighted mean] from=curBlockSize then=curBG");
         setOption("BlackBackground", true);
         run("Convert to Mask");
         if (itg == 1){
         roiManager("reset");
	     run("Analyze Particles...", "size=&curApSizeMin circularity=" + curCir + "-1.00 show=Masks clear add");
	     selectWindow("Mask of " + curTgt + "_m");
	     run("Invert LUTs");
         }
	     rename(curTgt + "_mw");
	     run("Watershed");
         
         // count target punctas inside the NM mask
	     selectWindow(curTgt + "_mw");
         roiManager("reset");
	     run("Analyze Particles...", "size=&curApSizeMin circularity=" + curCir + "-1.00 show=Masks clear add");
	     selectWindow("Mask of " + curTgt + "_mw");
	     run("Invert LUTs");
	     rename(curTgt + "_mask");
    }
    
//************ data saving ***************************
    // build composite of target channels
     run("Merge Channels...", "c1="+ cntTgt[0] + " c2=" + cntTgt[1] +" create keep");
     rename("CompositeRaw");
         Stack.setChannel(2);
	     run("Enhance Contrast", "saturated=0.35");
	     run(tgColor[tgChPos[1]-1]);
	     Stack.setChannel(1);
	     run("Enhance Contrast", "saturated=0.35");
	     run(tgColor[tgChPos[0]-1]);
    curEXn = newArray(0,0); //excluded partical counter
    curUp = newArray(0,0);
    curN = newArray(0,0);
    for (itg=0;itg<tgn;itg++){
    	curCh = tgChPos[itg];
        curTgt = cntTgt[itg];
        curpairTgt = pairTgt[itg];
        curApSizeMin = apSizeMin[itg];
        
        selectWindow(curTgt + "_mask");
        run("Select None");
        roiManager("reset");
        Roi.setDefaultGroup(0);
        roiManager("Show None");
        run("Analyze Particles...", "size=&0-Infinity clear add");
        roiManager("Deselect");
        roiManager("Save", outRoi+FN_2Droi[itg]);
        selectWindow(curTgt);
        roiManager("Show None");
        roiManager("Show All");
        roiManager("Measure");

        curN_or = nResults;
        curSize = newArray(0);
        curInt = newArray(0);
        exIdx = newArray(curN_or);
        gpIdx = newArray(curN_or);
        Array.fill(exIdx,0);
        Array.fill(gpIdx,0);
        
       
        for (ir=0; ir<curN_or; ir++) {
          selectWindow("Results");
          tmpA = getResult("Area",ir);
          tmpI = getResult("Mean",ir);
             curSize = Array.concat(curSize,tmpA);
             curInt = Array.concat(curInt,tmpI);  
        }

        Array.getStatistics(curSize, curMin, curMax, curAvgSize);
        run("Clear Results");
        
        // paring check with roi enlarged
        curN[itg] = curSize.length;
        curOverlap = newArray(curN[itg]);
        Array.fill(curOverlap,0);
        curIdx = newArray(curN[itg]);
        
        selectWindow(curpairTgt + "_mask");
        roiManager("Show None");
        if (prDis > 0){
           roiManager("select","ROI Manager");
           for (j = 0; j < roiManager("count"); j++) {
              roiManager("select", j);
              run("Enlarge...", "enlarge=prDis pixel");
              roiManager("update");
           }    
        }
        roiManager("Deselect");
        run("Select None");
        roiManager("Show None");
        roiManager("Show All");
        roiManager("Measure");
        selectWindow("Results");
        curUp[itg] = curN[itg];
        j=0;
        for (ir=0; ir<curN_or; ir++) {
           if (gpIdx[ir]==0) {  
          	curOverlap[j] = getResult("RawIntDen",ir); 
        	curIdx[j] = ir+1;
               if (curOverlap[j]>0){ 
               	  curUp[itg]--;   	
            	  gpIdx[ir] = 1; // mark the roi as paired
         	   }else{
         	   	  gpIdx[ir] = 0; // mark the roi a         	   	  
         	   }
            j++;
           }
        }
        selectWindow(curpairTgt + "_mask");
        roiManager("Show None");
        run("Select None");
          
        // update roi group info in the measurement results, un-enlarged, save roi.
        run("Clear Results");
        roiManager("reset");
        roiManager("Open", outRoi+FN_2Droi[itg]);
        for (ir=0; ir<curN_or; ir++) {
          	roiManager("select", ir);
            RoiManager.setGroup(gpIdx[ir]);
        }
        roiManager("Deselect");
        Roi.setDefaultGroup(0);
        RoiManager.selectGroup(0);
        roiManager("Set Color", "yellow");
        roiManager("Set Line Width", 1);
        RoiManager.selectGroup(1);
        roiManager("Set Color", "#00A8FF");
        roiManager("Set Line Width", 1);
        roiManager("Deselect");
        roiManager("Save", outRoi+FN_2Droi[itg]);
        
        // save area info
        run("Clear Results");  
        selectWindow(curTgt);
        roiManager("Show None");
        roiManager("Show All");
        roiManager("Measure");
     	run("Input/Output...", "jpeg=100 gif=-1 file=.csv copy_column copy_row save_column save_row");
         saveAs("Results", outXlsx + FN_area[itg] + athrBG[itg]+".csv"); 

             
        // save roi on zprj images.
        selectWindow("CompositeRaw");
        run("Duplicate...", "title="+curTgt+"-save duplicate");
        if (jpgZoom !=1){
        getDimensions(width, height, channels, slices, frames);
        run("Size...", "width=" + (width * jpgZoom) + " height=" + (height * jpgZoom) + " interpolation=Bilinear");
        ScaleImageWithROIs(curTgt + "-save",jpgZoom);  
        }
        selectWindow(curTgt + "-save");
        roiManager("Show All without labels");
        Roi.setDefaultGroup(0);
        RoiManager.selectGroup(0);
        roiManager("Set Color", "yellow");
        roiManager("Set Line Width", 1);
        RoiManager.selectGroup(1);
        roiManager("Set Color", "#00A8FF");
        roiManager("Set Line Width", 1);
//        RoiManager.selectGroup(2);
//        roiManager("Set Color", "#00A8FF");
        roiManager("Show None");
        roiManager("Show All without labels");
        //  roiManager("Show All");
        // roiManager("OR");
        setFont("Calibri", 22, "bold, antialised, white");
        drawString(curTgt + "_"+spName, 10, 24);
        run("Flatten"); 
        run("Input/Output...", "jpeg=100");
        saveAs("Jpeg", outJPG+ FN_Seg2D[itg]);
        roiManager("Reset");

        // update stats table
        selectWindow(curTgt + "Stats");
        Table.setColumn(spName + "-Idx",curIdx);
        Table.setColumn(spName + "-Area",curSize);
        Table.setColumn(spName + "-avgInt",curInt);
        Table.setColumn(spName + "-Overlap",curOverlap);
        Table.update();
        
        // update NM-stats table
        selectWindow("NMstats");
	    Table.set(cntTgt[itg]+ "Paired",i, curN[itg] - curUp[itg]);
	    Table.set(cntTgt[itg]+"#",i, curN[itg]);
	    Table.set(cntTgt[itg]+"Up",i, curUp[itg]);
	    Table.set(cntTgt[itg]+"AvgSize",i, curAvgSize);
	    Table.update();
    }
     

     
    // save the compostite jpg
     selectWindow("CompositeRaw"); 
     run("Duplicate...", "title=CompositeJPG duplicate");
     getDimensions(width, height, channels, slices, frames);
     run("Size...", "width=" + (width * jpgZoom) + " height=" + (height * jpgZoom) + " interpolation=Bilinear");
     setFont("Calibri", 22, "bold, antialised, white");
     drawString(spName, 10, 24);
     run("Flatten");
     run("Input/Output...", "jpeg=100");
     saveAs("Jpeg",  outJPG + Seg2D_jpeg);
     
     // save composite tif
     selectWindow("CompositeRaw");
     save(outRoi + Seg2D_tif);
     
     // save masks
     run("Merge Channels...", "c1="+cntTgt[0]+"_mask c2=" + cntTgt[1] + "_mask create keep");
     Stack.setChannel(2);
     run(tgColor[tgChPos[1]-1]);
     Stack.setChannel(1);
     run(tgColor[tgChPos[0]-1]);
     save(outRoi + msk_tif);
     rename("CompositeMSK");
     getDimensions(width, height, channels, slices, frames);
     run("Size...", "width=" + (width * jpgZoom) + " height=" + (height * jpgZoom) + " interpolation=Bilinear");
     setFont("Calibri", 22, "bold, antialised, white");
     drawString(spName, 10, 24);
     run("Duplicate...", "title=CompositeMSK1 duplicate");
     roiManager("Show None");
     if (bgThrTog[0]>0 ){
	     roiManager("reset");
	     roiManager("Open", outRoi+FN_2Droi[0]);
	     if (curUp[0]>0){
	     RoiManager.selectGroup(0); //upaired group
	     roiManager("delete");
	     }
	     if (curUp[0]!=curN[0]){
	     RoiManager.selectGroup(1); //paired group
	     roiManager("delete");
	     }
      if (curEXn[0]>0){
     	 ScaleImageWithROIs("CompositeMSK1",jpgZoom);
     	 selectWindow( "CompositeMSK1"); 
//	     roiManager("Show None");
	     roiManager("Show All without labels");
	 	 roiManager("select all");
	 	 roiManager("Set Color","#00A8FF");//"#00A8FF"
	     roiManager("Set Line Width", 1);
//	     roiManager("deselect");
	     }
     }
     run("Select None");
     run("Flatten");
     run("Input/Output...", "jpeg=100");
     saveAs("Jpeg",  outJPG + msk_jpeg);
     roiManager("Deselect");

     // save hc
     selectWindow("hc");
     resetMinAndMax();
     run("Enhance Contrast", "saturated=0.35");
     run("8-bit");
     getDimensions(width, height, channels, slices, frames);
     run("Size...", "width=" + (width * jpgZoom) + " height=" + (height * jpgZoom) + " interpolation=Bilinear");
     run("Flatten");
     run("Input/Output...", "jpeg=100");
     saveAs("Jpeg", outJPG +Seg2D_hc);
     
     run("Close All");
     if (isOpen("Results")) {
             selectWindow("Results"); 
             run("Close" );
      }
}
//xxxxxxxxxxxxxxxxxxxxxx End of the processing loop xxxxxxxxxxxxxxxxxxxxxx

// Save stats tables
selectWindow("NMstats");

run("Input/Output...", "jpeg=100 gif=-1 file=.csv copy_column copy_row save_column save_row");
saveAs("Results", masterFileNM );

selectWindow(cntTgt[0] + "Stats");
run("Input/Output...", "jpeg=100 gif=-1 file=.csv copy_column copy_row save_column save_row");
 saveAs("Results",  masterFileTg1 );
 
selectWindow(cntTgt[1] + "Stats");
run("Input/Output...", "jpeg=100 gif=-1 file=.csv copy_column copy_row save_column save_row");
 saveAs("Results",  masterFileTg2);


setBatchMode("exit and display");
print("--- All Done ---");

// --- Main procedure end ---
//###############################################################################

function getFromFileList(ext, fileList)
{
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

function printArray(array)
{
  // Print array elements recursively
  for (i=0; i<array.length; i++)
    print(array[i]);
}

function getExtension(filename)
{
  ext = substring( filename, lastIndexOf(filename, ".") + 1 );
  return ext;
}

// get 95% confidence interval of median
function UpperBound(arr) {
  N = arr.length; 
  Array.sort(arr);
  if (N>2){
   lowerQuartileIndex = round(N * 0.25);
   upperQuartileIndex = round(N * 0.75);
   lowerQuartile = arr[lowerQuartileIndex];
   upperQuartile = arr[upperQuartileIndex];
   iqr = upperQuartile - lowerQuartile;
   upperBound = upperQuartile + 1.5 * iqr;
  }else{
  	upperBound = arr[N-1];
  }
  return upperBound;
}

function ScaleImageWithROIs(imageName,zoomfactor){
	selectWindow(imageName);
	run("Duplicate...", "title="+imageName+"2 duplicate");
//	roiManager("deselect");
	roiManager("Show None");
	roiManager("Show All without labels");
	rn = roiManager("count");
//	print("inside rn="+rn);
	if (zoomfactor!=1){
	     for(ir=0; ir<rn; ir++) {
	        roiManager("Select", 0);
	        gp = Roi.getGroup;
	//        print(gp);
	        Roi.getCoordinates(xpoints, ypoints);
	        for(j=0; j<xpoints.length; j++) {
	            xpoints[j]*=zoomfactor;
	            ypoints[j]*=zoomfactor;
	        }
	        roiManager("Select", 0);
	        roiManager("delete");
//	        rna=roiManager("count");
	//        print(i+"rna"+rna);
	        makeSelection("polygon",xpoints, ypoints);
	        roiManager("Add");
	        roiManager("Select", rn-1);
	        RoiManager.setGroup(gp);        
	    }
	}
    roiManager("Deselect");
    run("Select None");
}
