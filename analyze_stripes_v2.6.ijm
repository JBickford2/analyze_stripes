macro "Analyze_Stripes [f1]" {

/* Written by Justin Bickford
 *  I suggest running in Fiji, although this macro will certainly work in ImageJ1.
 *  
 *  v2.6 (20190213) corrected another error with the roiManager("combine") function. The
 *  macro would error out when only a single item was in a group.
 *  
 *  v2.5 (20180312) corrected an error with the roiManager("combine") function.
 *  
 *  v2.4.5b (20180116) corrected an error with the stripe angle calculation.
 *  
 *  v2.4.5 (20170612) had to remove "roiManager("Save Selected"..." portion to prevent an
 *  an error that cropped up with a new FIJI patch push.
 *  
 *  v2.4.4 (20140707) now converts all images to 8-bit grayscale after opening.  This will
 *  lower the dynamic range of any 16-bit grayscale images, but will convert any color
 *  images to grayscale. I have yet to analyze a 16-bit image anyway.
 *  
 *  v2.4.3 (20140123) fixed an error in my rms edge roughness error propagation.
 *  
 *  v2.4.1 (20130610) found a more efficient and more stable way of correcting the 
 *  nearly horizontal line bug.
 *  
 *  v2.4 (20130607) bug fixed regarding nearly horizontal lines.
 *  
 *  v2.3 (20130415) bug fixed regarding when script attempts to close windows that are
 *  already closed by user.  Added instructions output to the Log window.
 *  
 *  v2.2 (20130401) writes a tab-delimited file with the results for import into Excel.
 *  It always appends to the same file in the same directory as the last opened image.
 *  
 *  v2.1 (20130328) uses gradient^4 and selects a threshold based on the mean value.  It's
 *  pretty robust, but I still kept in the part that allows the user to choose a different
 *  threshold value if they desire.
 *  
 *  v3.0 (20130328) SPUR attempted to implement a wand method, but stopped after success
 *  with v2.1.
 *  
 *  v2.0 (20130327) gives a slightly better estimate for the threshold and lets the user
 *  decide the final threshold value.  It no longer keeps lowering the threshold.
 *  
 *  v1.2 (20130320) keeps lowering the threshold until it finds at least two distinct
 *  edges.
 *  
 *  v1.1 (20130320) makes sure there are at least two edges to avoid errors.
 *  
 *  v1.0 (20130320) first port of my Matlab script.

 Copyright 2013 Justin R. Bickford. 

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the “Software”), copy, modify, merge, publish,
or otherwise alter this software for educational or academic purposes subject to the
following conditions: 

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software. 

The copyright holders of other software modified and included in the Software retain their
rights and the licenses on that software should not be removed.

Cite the author (above) of this macro in any publication that relies on the Software. Also
cite those projects on which the Software relies when applicable.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE. 
 */

// house cleaning
if (isOpen("Results")){
	selectWindow("Results");
	run("Close");		// closes the Results window only
}
if (isOpen("ROI Manager")){
	selectWindow("ROI Manager");
	run("Close");		// closes the ROI Manager window only
}

// output instructions if the Log is not open (ie: only for the first session of this script)
if (!isOpen("Log"))
	print("Instructions:\n  When drawing the ROI, note that only the outermost edges will be analyzed, inner edges will be ignored.  \nFeel free to use the freehand tool to 'carve-out' bad segments of your stripe; just be sure to draw a \nclosed selection.  Stripes of any orientation are valid.\n  This script will do its best to guess a reasonable global threshold value, but the user has the final say; \nif you don't like how the highlighted regions accent your edges, simply adjust the Threshold sliders and \nclick OK to continue.  The ideal selection is where both edges of interest are contiguous narrow lines \ndistinct from any other feature.\n  In addition to the output in this Log window, all results are appended to a data file named: \n'Analyze_Stripes_log.txt' placed in each analyzed image's directory.  This tab-delimited file may be \nopened in your spreadsheet program of choice.\n ");


// prompt to open an image
Imagename = File.openDialog("Open an Image to analyze");
if (Imagename=="")
	exit();
write("Image name = "+Imagename);
open(Imagename);
getPixelSize(unit, pw, ph, pd);
if ( unit=="" || unit==" " || unit=="pixels" ) {
	unit = "pixels";
	print("To calibrate units: 1) open a calibration image, 2) draw a line along a known distance, 3) choose Analyze/Set Scale...");
}

run("8-bit");	// This is a quick fix for color images, but will downconvert any 16-bit grayscale image resulting in lower dynamic range.

// prompt to crop to ROI
setTool("rectangle");
run("Select All");	// just prevents errors if nothing is selected by the user
waitForUser("ROI Selection", "Draw a Region of Interest and click OK\n \nNOTE- all closed shapes are valid including:\n  rectangle, ellipse, polygon, and freehand.");
run("Crop");
run("16-bit");	// normalize equalize requires a maximum of 16-bit
run("Enhance Contrast...", "saturated=0");// equalize");
saveAs("Tiff", getDirectory("temp")+"tmp_cropped.tif");	// saves image to revert to later

// find edges
run("Set Measurements...", "area mean standard min centroid fit redirect=None decimal=3");
roiManager("reset");
run("32-bit");
run("Find Edges");
run("Square");	// turns the gradient into gradient squared
run("Square");	// further enhances the good edges
run("Enhance Contrast", "saturated=0");

run("Select All");
getStatistics(area, mean, min, max);
setThreshold(8*mean,max);

//*  This part allows the user to tweak the threshold if necissary
run("Threshold...");
waitForUser("Adjust the threshold to highlight only\nedges of interest, then click OK.");
run("View 100%");
if (isOpen("Threshold")){
	selectWindow("Threshold");
	run("Close");
}
//*/

run("Convert to Mask");
//run("Dilate");
run("Skeletonize");
run("Analyze Particles...", "size=0-Infinity circularity=0.00-0.10 show=Nothing clear include add");
run("Clear Results");	// makes sure the Results are cleared before analyzing
roiManager("Measure");

// determine the average angle orientation
sina = 0;
cosa = 0;
for (n=0;n<nResults;n++) {
	area =  getResult("Area", n);
	angle = getResult("Angle", n);
	sina = sina+area*sin(angle*PI/180);
	cosa = cosa+area*cos(angle*PI/180);
}
aveangle = (180/PI)*atan(sina/cosa);	// this is the area weighted average angle

print("average angle = "+aveangle+" degrees");

// rotate the data (not the image itself)
run("Select All");
run("32-bit");	// this allows the v=... pixel math to generate 32-bit values rather than 8-bit integers
run("Macro...", "code=[v= x*sin(PI/180*("+aveangle+"))+y*cos(PI/180*("+aveangle+"))]");
run("Clear Results");
roiManager("Measure");

// collect data
n = nResults;
//print(n);
roiindex = newArray(n);
mean = newArray(n);
rms = newArray(n);
extrema = newArray(n);
for (i=0;i<n;i++) {
	roiindex[i] = i;
	mean[i] = getResult("Mean", i);
	rms[i] = getResult("StdDev", i);
	extrema[i] = getResult("Max", i)-getResult("Min", i);
}
//Array.print(roiindex);
// sort data by Mean
do {
	newn = 0;
	for (i=1;i<n;i++) {
		if (mean[i-1]>mean[i]) {
			// swap mean[i-1] with mean[i]
			tmp = mean[i-1];
			mean[i-1] = mean[i];
			mean[i] = tmp;
			
			// swap rms[i-1] with rms[i]
			tmp = rms[i-1];
			rms[i-1] = rms[i];
			rms[i] = tmp;

			// swap extrema[i-1] with extrema[i]
			tmp = extrema[i-1];
			extrema[i-1] = extrema[i];
			extrema[i] = tmp;
			
			// swap roiindex[i-1] with roiindex[i]
			tmp = roiindex[i-1];
			roiindex[i-1] = roiindex[i];
			roiindex[i] = tmp;
			
			newn = i;
		}
	}
	n = newn;
} while (n != 0);
//Array.print(roiindex);

// analyze data
similarity = 5;	// controls how wide to cast the net of similarity

// collect ROI's to combine into group1
group1 = newArray(1);	// though not necissary, this is the most compatible method
Array.fill(group1,roiindex[0]);
for (i=1;i<(nResults-1);i++) {
	if ( (mean[i]-similarity*rms[i]) < (mean[0]+similarity*rms[0]) ) {	// if the lines are similar to the minimum line, add them to group1
		group1 = Array.concat(group1,roiindex[i]);
	}
}
//print("group1:");
//Array.print(group1);

// collect ROI's to combine into group2
group2 = newArray(1);
Array.fill(group2,roiindex[nResults-1]);
for (i=(nResults-2);i>1;i--) {
	if ( (mean[i]+similarity*rms[i]) > (mean[nResults-1]-similarity*rms[nResults-1]) ) {	// if the lines are similar to the maximum line, add them to group2
		group2 = Array.concat(roiindex[i],group2);
	}
}
//print("group2:");
//Array.print(group2);
//getNumber("prompting for a number just to pause the program",0);
// measure all ROI's in each group, exclusive of ROI's outside both groups
roiManager("Show All without labels");	// removes the labels, which a user may find confusing in the context of this macro
run("Clear Results");	// clears contents of Results
run("Select None");	// deselects everything in the image window

roiManager("Select", group1);
if (lengthOf(group1)>1) {
	roiManager("Combine");
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
}
roiManager("Measure");

roiManager("Select", group2);
if (lengthOf(group2)>1) {
	roiManager("Combine");
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
}
roiManager("Measure");

// analyze data
linewidth = getResult("Mean", 1) - getResult("Mean", 0);
RMS_edge_roughness = sqrt( ( pow( getResult("StdDev", 1), 2 ) + pow( getResult("StdDev", 0), 2 ) )/2 );	// this is the correct form
pkpk_edge_roughness = maxOf(getResult("Max", 1) - getResult("Min", 1),getResult("Max", 0) - getResult("Min", 0));


// output data
toScaled(linewidth);
toScaled(RMS_edge_roughness);
toScaled(pkpk_edge_roughness);
print("linewidth = "+d2s(linewidth,-3)+" "+unit);
if (linewidth==0)
	print("Failed to find two distinct edges.");
print("RMS edge roughness (Rq)= "+d2s(RMS_edge_roughness,-3)+" "+unit);
print("peak-to-peak edge roughness (Rt)= "+d2s(pkpk_edge_roughness,-3)+" "+unit);
print(" ");

// reverts to the cropped image and overlays the ROI's
run("Revert");
run("From ROI Manager");


// house cleaning
if (isOpen("Results")){
	selectWindow("Results");
	run("Close");		// closes the Results window only
}
if (isOpen("ROI Manager")){
	selectWindow("ROI Manager");
	run("Close");		// closes the ROI Manager window only
}


// write output to file
shortimagename = File.nameWithoutExtension;
logfile = File.directory+File.separator+"Analyze_Stripes_log.txt";
if (!File.exists(logfile))
	File.append("image name \tlinewidth \tRMS edge roughness (Rq) \tpeak-to-peak edge roughness (Rt) \tunits",logfile);
File.append(shortimagename+" \t"+linewidth+" \t"+RMS_edge_roughness+" \t"+pkpk_edge_roughness+" \t"+unit,logfile);
//File.close(logfile);	// file will close automatically when macro exits
}
