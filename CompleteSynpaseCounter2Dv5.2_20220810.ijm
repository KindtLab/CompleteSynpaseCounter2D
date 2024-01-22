//            ********************************************************
//            ** Neuromast_CompleteSynaspseCounter2D 5.2, Kindt Lab **
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

// ########################################################################################
// Parameter Settings 
  // ----------------------------------------------------------------------------------------
  //  !!! Z-prj of channels should be named as: sampleNames + chsSuffix + Prj.tif 
  //  !!! Segmentation of channels should be named as: sampleNames + chsSuffix + Seg.tif
  // -----------------------------------------------------------------------------------------

  // Counting configurations:
  tgn = 2; // number of counting targets
  cntTgt = newArray(    "ctbp",    "mag",    "NA"); // counting targets
  pairTgt = newArray(    "mag",   "ctbp",    "NA"); // pairing target
  tgColor = newArray("Magenta",  "Green", "Grays"); //
  tgChPos = newArray(        2,        3,    "NA"); // target channel position
  bgThrTog = newArray(       0,        0,    "NA"); // target channel tog for background size&int thresholding
  bgThrUL = newArray(     0.06,      0.1,    "NA"); // maximum size for background particals
  tgContrast = newArray(  0.01,     0.01,    "NA"); // target channel contrast
  apSizeMin=newArray(    0.025,     0.04,    "NA"); // 2D size threshold for "Analyze Particle", 
  circularMin = newArray(  0.3,      0.3,    "NA"); // 2D circularity threshold for "Analyze Particle", 
  manualAdp = newArray(      0,        2,       0); // option to manually determin adaptive thresholding parameters for each sample 1: interactive, 2: pre-determined
  athrBlockSize=newArray(   70,      110,    "NA"); // adaptive thresholding block size,
  athrBG = newArray(       -20,      -30,    "NA"); // adaptive thresholding backgroud, 
  enWatershed = newArray(    0,        0,    "NA");
  enWed_radius = newArray(   3,        0,       0);
  engPix = 2; //enlarge rois for overlapping calculation (by pixs)
  jpgZoom = 2; //zoom factor for saved jpg
  
  // in the ch sequence:
  chHairCell = 1; // HC channel position
  chsSuffix = newArray( "_hc",  "_ctbp",   "_mag"); //tag of singal channel Z-prj
  chN = chsSuffix.length; // number of channels 
  suffix_for_HCmsk = "_hc_msk"; //if there's a mask, name it as ImageName + suffix_for_HCmsk
  
  
  //Stats table headers
  NMheaders = newArray("SampleID", 
              cntTgt[0]+"Paired",cntTgt[0]+"#", cntTgt[0]+"Up", cntTgt[0]+"AvgSize", cntTgt[0]+"adpBlockSize", cntTgt[0] +"adpBG", cntTgt[0]+"SizeThr", cntTgt[0] +"IntThr", 
              cntTgt[1]+"Paired",cntTgt[1]+"#", cntTgt[1]+"Up", cntTgt[1]+"AvgSize", cntTgt[1]+"adpBlockSize", cntTgt[1] +"adpBG", cntTgt[1]+"SizeThr", cntTgt[1] +"IntThr");
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
outXlsx = outDir + File.separator + "xlsx" + File.separator;
if (!File.exists(outXlsx)) {
    File.makeDirectory(outXlsx);
}
outRoi = outDir + File.separator+ "Rois" + File.separator;
if (!File.exists(outRoi)) {
    File.makeDirectory(outRoi);
}
outJPG = outDir + File.separator + "Jpgs" + File.separator;
if (!File.exists(outJPG)) {
    File.makeDirectory(outJPG);
}
inZprj = inDir + File.separator + "chPrj" + File.separator;
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

// Checkpoint: get list of dirs
print("Below is a list of files to be processeded:");
printArray(list); // Implemented below
print("Result save to:");
print(outDir);

// save parameter to txt file
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
f = File.open(paraFile);
print(f, "Parameters used as follow: ( " + year +"-"+ month+"-" + dayOfMonth +"_"+ hour+"-"+ minute+"-"+ second + ")");
print(f, "channel config = " + chsSuffix[0] + ";" + chsSuffix[1] + ";" + chsSuffix[2]);
print(f, "Counting configs:");
print(f, "Counting targets = " + cntTgt[0] + ";" + cntTgt[1] + ";" + cntTgt[2]);
print(f, "AnalyzeParticles sizeMin = " + apSizeMin[0] + ";" + apSizeMin[1] + ";" + apSizeMin[2]);
print(f, "AnalyzeParticles circularityMin = " + circularMin[0] + ";" + circularMin[1] + ";" + circularMin[2]);
print(f, "AdaptiveTHR blockSize = " + athrBlockSize[0] + ";" + athrBlockSize[1] + ";" + athrBlockSize[2]);
print(f, "AdaptiveTHR background = " + athrBG[0] + ";" + athrBG[1] + ";" + athrBG[2]);
print(f, "contrast per target = " + tgContrast[0] + ";" + tgContrast[1] + ";" + tgContrast[2] );
print(f, "Background thr per target = " + bgThrTog[0] + ";" + bgThrTog[1] + ";" + bgThrTog[2]);
print(f, "Background thr maximum size per target = " + bgThrUL[0] + ";" + bgThrUL[1] + ";" + bgThrUL[2]);
print(f, "Enhanced Watershed tog = " + enWatershed[0] + ";" + enWatershed[1] + ";" + enWatershed[2] );
print(f, "Enhanced Watershed XY radius = " + enWed_radius[0] + ";" + enWed_radius[1] + ";" + enWed_radius[2]);
print(f, "engPix = " + engPix);
print(f, "jpgZoom = " + jpgZoom);
File.close(f);

//
//  athrBG_tg1 = newArray(-32,-35,-35,-50,-32,
//  						-40,-20,-30,-32,-40,
//  						-30,-40,-28,-40,-37,
//  						-35,-30,-37);
//  
//   for selected group
  athrBG_tg2 = newArray(-35,-35,-26,-25,-35,
                        -40,-30,-50,-35,-32,
                        -32,-30,-32,-26,-40,
                        -40,-22,-35,-32,-35,
                        -23,-35,-30,-40,-38,
                        -35,-30,-30,-32,-42,
                        -35,-32,-30,-25,-32,
                        -32,-35,-30,-40,-45,
                        -35,-35,-32,-35);
    //for A-score group
//  athrBG_tg2 = newArray(-35,-40,-35,-20,-30,
//                        -38,-35,-35,-30,-40,
//                        -30,-33,-38,-35,-35,
//                        -30,-37,-30,-25,-25,
//                        -35,-38,-33,-35,-35,
//                        -42,-35,-35,-32,-35,
//                        -32,-32,-35,-40,-35,
//                        -35,-35,-32,-35,-37);
       //for S-score group                 
//  athrBG_tg2 = newArray(-35,-26,-30,-30,-28,
//                        -35,-30,-35,-35,-32,
//                        -32,-32,-32,-32,-32,
//                        -32,-32,-35,-35,-30,
//                        -32,-30,-30,-25,-24,
//                        -30,-30,-32,-24,-35,
//                        -33);
//       //for new samples
//athrBG_tg2 = newArray(-26,-40,-42,-50,-40,
//                      -42,-40,-15,-35,-23,
//                      -34,-35,-30,-40,-35,
//                      -25,-30,-32,-30,-45,
//                      -40,-17,-37,-40,-40,
//                      -32,-30);
// For B-score aM 
//athrBG_tg2 = newArray(-40,-45,-33,-30,-30,-45,-40,-35);

//###################################################################################
// --- Main Processing starts here ---

roiManager("show none"); // to avoid a weird error of the ROImanager reset function
run("Set Measurements...", "area mean centroid shape integrated add redirect=None decimal=3");
Array.getStatistics(manualAdp, adpMin, adpMax);
print(adpMin,adpMax);
if (adpMax>0){
	setBatchMode(false);
}else{
	setBatchMode(true);
}
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
  
  inFullnamePrjs = newArray(inZprj + spName + chsSuffix[0] + "Prj.tif",
                            inZprj + spName + chsSuffix[1] + "Prj.tif",
                            inZprj + spName + chsSuffix[2] + "Prj.tif");
                            
  inFullnameSegs = newArray(inDir + spName + chsSuffix[0] + "Seg.tif",
                            inDir + spName + chsSuffix[1] + "Seg.tif",
                            inDir + spName + chsSuffix[2] + "Seg.tif");
  
    FN_2Droi = newArray(spName + "_" + cntTgt[0] + "2Droi.zip",
                        spName + "_" + cntTgt[1] + "2Droi.zip",
                        spName + "_" + cntTgt[2] + "2Droi.zip");
                   
    FN_BG = newArray(spName + "_BG" + cntTgt[0] + ".jpeg",
                     spName + "_BG" + cntTgt[1] + ".jpeg",  
                     spName + "_BG" + cntTgt[2] + ".jpeg");
                        
    FN_count = newArray(spName + "_" + cntTgt[0] + "Count.csv",
                        spName + "_" + cntTgt[1] + "Count.csv",
                        spName + "_" + cntTgt[2] + "Count.csv");
                        
    FN_area = newArray(spName + "_" + cntTgt[0] + "Area_thr-",
                       spName + "_" + cntTgt[1] + "Area_thr-",
                       spName + "_" + cntTgt[2] + "Area_thr-");
    
    FN_Seg2D = newArray(spName  + "_Seg" + cntTgt[0] + ".jpeg",
                        spName  + "_Seg" + cntTgt[1] + ".jpeg", 
                        spName  + "_Seg" + cntTgt[2] + ".jpeg");
    
    FN_CountBG = newArray(spName + "_" + cntTgt[0] + "CountBG.csv",
                          spName + "_" + cntTgt[1] + "CountBG.csv",
                          spName + "_" + cntTgt[2] + "CountBG.csv");
                            
    
    FN_manualAdp = spName + "_manualAdp.txt"; 
    FN_EXroi = spName + "_EXroi.zip";
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
	         run("Convert to Mask");
	         run("Duplicate...", "title=HCmsk_rev");
	         run("Invert");
	         imageCalculator("Or", "HCmsk", "HCmsk_rev");
             close("HCmsk_rev");
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
    BGSizeThr = newArray(0,0);
    BGIntThr = newArray(1,1);
    AdpThr = newArray(0,0);
    for (itg = 0;itg<tgn;itg++){
         curCh = tgChPos[itg];
         curTgt = cntTgt[itg];
         curBlockSize = athrBlockSize[itg];
         curBG = athrBG[itg];
         if (manualAdp[itg] == 2){
           if (itg==0){
         	curBG = athrBG_tg0[i];
            }
           if (itg==1){
         	curBG = athrBG_tg1[i];
            }
         }
         curContrast = tgContrast[itg];
         curApSizeMin = apSizeMin[itg];
         curCir = circularMin[itg];
         selectWindow("C" + curCh + "-Current");
         rename(curTgt);
         imageCalculator("Multiply create", curTgt, "HCmsk");
         rename(curTgt + "_m");
         resetMinAndMax();
         run("Enhance Contrast", "saturated=" + curContrast);
         getMinAndMax(chMin, chMax);
         run("Apply LUT");
         run("8-bit");
         run("Duplicate...", "title="+curTgt+"_tryAdp");
         if (manualAdp[itg]==1){
         	waitForUser("try adaptive thresholding, then hit OK");   
//         	curBlockSize=getNumber("Which block size did you set?", curBlockSize);
         	curBG=getNumber("Which background level did you set?", curBG);
         }
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
	     
         if (enWatershed[itg]==0){
	         run("Watershed");
         }else{ 
			//******* enhanced watershed = maximal lobal + 3D watershed
            //  create adptive shreholded gray-scale image
         	rename(curTgt + "_ma"); //ma = masked by adaptive thresholding
        	run("Divide...", "value=255.000");
			imageCalculator("Multiply create", curTgt , curTgt + "_ma");
			selectImage("Result of " + curTgt);
			rename(curTgt + "_mg"); // mg = masked gray
			
            // find local maximum 
            selectWindow(curTgt + "_mg");
            getPixelSize(unit, px, py, pz);
			filters_parameters=
			  "filter=" + "MaximumLocal" +
			  " radius_x_pix=" + d2s(enWed_radius[itg],1) +
			  " radius_y_pix=" + d2s(enWed_radius[itg],1) +
			  " radius_z_pix=" + d2s(1,1) +
			  " Nb_cpus=8";
			 run("3D Fast Filters",filters_parameters);
			 rename(curTgt + "_3DLM"); // 3DLM = 3D maximum local
             
             // 3D watershed
			watershed_parameters=
			  "seeds_threshold=" + 0 +
			  " image_threshold=" + 0 +
			  " image=" + curTgt  + "_mg" +
			  " seeds=" + curTgt + "_3DLM" +
			  " radius=" + enWed_radius[itg];
			run("3D Watershed", watershed_parameters);
			setMinAndMax(0, 1);
			run("Apply LUT");
			run("Convert to Mask");
			rename(curTgt + "_mw");
			run("Properties...", "unit=micron pixel_width=px pixel_height=py voxel_depth=pz");
         }
         
         // count target punctas inside the NM mask
	     selectWindow(curTgt + "_mw");
         roiManager("reset");
	     run("Analyze Particles...", "size=&curApSizeMin circularity=" + curCir + "-1.00 show=Masks clear add");
	     selectWindow("Mask of " + curTgt + "_mw");
	     run("Invert LUTs");
	     rename(curTgt + "_mask");

         // find intensity and size upper bounds of the punctas in the background if there's a NM mask
         if (manualMask>0 && bgThrTog[itg]>0){
            imageCalculator("Multiply create",curTgt,"BG");
          	rename("BG"+ curTgt);
          	resetMinAndMax();
	        setMinAndMax(chMin, chMax);
	        run("8-bit");
	        run("adaptiveThr ", "using=[Weighted mean] from=curBlockSize then=curBG");
            setOption("BlackBackground", true);
            run("Convert to Mask");
            run("Watershed");
            saveAs("Jpeg", outJPG+ FN_BG[itg]);
            roiManager("reset");
          	run("Analyze Particles...", "size=&0-bgThrUL[itg] show=Masks clear add");
          	if (roiManager("count")>0){
	          	selectWindow(curTgt);
	            roiManager("Show None");
	            roiManager("Show All");
	            roiManager("OR");
	            roiManager("Measure");
	            selectWindow("Results");
	            curBGSize = newArray(nResults,1);
	            curBGInt = newArray(nResults,1);
	            curBGn = nResults;
	              for (ib=0; ib<nResults; ib++) {
	                curBGSize[ib] = getResult("Area",ib);
	                curBGInt[ib] = getResult("Mean",ib);
	              }
	              if (curBGn>1){
		              BGSizeThr[itg] = UpperBound(curBGSize);
		              BGIntThr[itg] = UpperBound(curBGInt);
		              
	              }else{
	              	  BGSizeThr[itg] = curBGSize[0];
		              BGIntThr[itg] = curBGInt[0];
	              }
	            run("Input/Output...", "jpeg=100 gif=-1 file=.csv copy_column copy_row save_column save_row");
	            saveAs("Results", outXlsx + FN_CountBG[itg] );
	            run("Clear Results");
            }
          }
          AdpThr[itg] = curBG; 
    }
    
//************ data saving ***************************
    // build composite of target channels
     run("Merge Channels...", "c1="+ cntTgt[0] + " c2=" + cntTgt[1] +" create keep");
     rename("CompositeRaw");
         Stack.setChannel(2);
	     run("Enhance Contrast", "saturated=0.35");
	     run(tgColor[1]);
	     Stack.setChannel(1);
	     run("Enhance Contrast", "saturated=0.35");
	     run(tgColor[0]);
    curEXn = newArray(0,0); //excluded partical counter
    curUp = newArray(0,0);
    curN = newArray(0,0);
    for (itg=0;itg<tgn;itg++){
    	curCh = tgChPos[itg];
        curTgt = cntTgt[itg];
        curpairTgt = pairTgt[itg];
        curApSizeMin = apSizeMin[itg];
        curSizeThr = BGSizeThr[itg];
        curIntThr = BGIntThr[itg];
        
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
        
        // exclude puctas smaller and weaker than the upper bounds of paticals in the backgroud
        for (ir=0; ir<curN_or; ir++) {
          selectWindow("Results");
          tmpA = getResult("Area",ir);
          tmpI = getResult("Mean",ir);
            if  (tmpA > curSizeThr || tmpI > curIntThr){ 
             curSize = Array.concat(curSize,tmpA);
             curInt = Array.concat(curInt,tmpI);  
           }else{
             gpIdx[ir] = 2; // mark the roi as backgroud group
             curEXn[itg]++;
           }
        }

//        selectWindow(curTgt);
//        run("Clear Results");
//        roiManager("Show None");
//        roiManager("Show All");
//        roiManager("OR");
//        roiManager("Measure");
//        run("Input/Output...", "jpeg=100 gif=-1 file=.csv copy_column copy_row save_column save_row");
//        saveAs("Results", outXlsx + FN_area[itg] );
        Array.getStatistics(curSize, curMin, curMax, curAvgSize);
//        print(curAvgSize);
        run("Clear Results");
        
        // paring check with roi enlarged
        curN[itg] = curSize.length;
        curOverlap = newArray(curN[itg]);
        Array.fill(curOverlap,0);
        curIdx = newArray(curN[itg]);
        
        selectWindow(curpairTgt + "_mask");
        roiManager("Show None");
        if (engPix > 0){
           roiManager("select","ROI Manager");
           for (j = 0; j < roiManager("count"); j++) {
              roiManager("select", j);
              run("Enlarge...", "enlarge=engPix pixel");
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
         saveAs("Results", outXlsx + FN_area[itg] + AdpThr[itg]+".csv"); 

             
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
	    Table.set(cntTgt[itg]+"SizeThr",i, curSizeThr);
	    Table.set(cntTgt[itg]+"IntThr",i, curIntThr);
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
     run(tgColor[1]);
     Stack.setChannel(1);
     run(tgColor[0]);
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
