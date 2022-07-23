#include <opencv2/core/core.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <string>
#include <iomanip>
#include <cstring>
#include <sstream>
#include <iostream>
#include <cstdio>
#include <tr1/memory>
#include <stdlib.h>
#include <signal.h>
#include <fstream>
#include <algorithm>

#include "include/allsky_common.h"

#include "include/raspistill.h"
#include "include/mode_mean.h"

// These only need to be as large as modeMeanSetting.historySize.
const int historySize = 5;
double meanHistory [historySize];
int exposureLevelHistory [historySize];

int MeanCnt				= 0;		// how many means have we calculated?
double dMean			= 1.0;		// Mean(n-1)-Mean(n): prior mean minus current mean
int dExp				= 1.0;		// Exp(n-1)-Exp(n):   prior exposure minus current exposure
int lastExposureChange	= 0;
int dExposureChange		= 0;
bool fastforward		= false;


int calcExposureLevel(int exposure_us, double gain, modeMeanSetting &currentModeMeanSetting)
{
	return log(gain  * exposure_us/(double)US_IN_SEC) / log (2.0) * pow(currentModeMeanSetting.shuttersteps,2.0);
}

double calcExposureTimeEff (int exposureLevel, modeMeanSetting &currentModeMeanSetting)
{
	return pow(2.0, double(exposureLevel)/pow(currentModeMeanSetting.shuttersteps,2.0));
}

// set limits.  aeg == Auto Exposure / Gain
bool aegInit(config cg, int minExposure_us, double minGain,
		raspistillSetting &currentRaspistillSetting, modeMeanSetting &currentModeMeanSetting)
{
	// Init some values first
	static int initialExposureLevel = 0;
	if (currentModeMeanSetting.init) {
		currentModeMeanSetting.init = false;

		if (historySize < currentModeMeanSetting.historySize) {
			fprintf(stderr, "*** INTERNAL ERROR: historySize (%d) < currentModeMeanSetting.historySize (%d)\n", historySize, currentModeMeanSetting.historySize);
			return false;
		}

		// XXXXXX    Does this need to be done every transition between day and night,
		// or just once when Allsky starts?
		// first exposure with currentRaspistillSetting.shutter_us, so we have to calculate the startpoint for ExposureLevel
		initialExposureLevel = calcExposureLevel(cg.currentExposure_us, cg.currentGain, currentModeMeanSetting) - 1;
		currentModeMeanSetting.exposureLevel = initialExposureLevel;
		currentRaspistillSetting.shutter_us = cg.currentExposure_us;

		for (int i=0; i < currentModeMeanSetting.historySize; i++) {
			// Pretend like all prior images had the target mean and initial exposure level.
			meanHistory[i] = currentModeMeanSetting.meanValue;
			exposureLevelHistory[i] = initialExposureLevel;
		}
	}

	// check and set meanAuto
	if (cg.currentAutoGain && cg.currentAutoExposure)
		currentModeMeanSetting.meanAuto = MEAN_AUTO;
	else if (cg.currentAutoGain)
		currentModeMeanSetting.meanAuto = MEAN_AUTO_GAIN_ONLY;
	else if (cg.currentAutoExposure)
		currentModeMeanSetting.meanAuto = MEAN_AUTO_EXPOSURE_ONLY;
	else
		currentModeMeanSetting.meanAuto = MEAN_AUTO_OFF;

	// calculate min and max exposurelevels
	if (currentModeMeanSetting.meanAuto == MEAN_AUTO) {
		currentModeMeanSetting.exposureLevelMax = calcExposureLevel(cg.currentMaxAutoExposure_us, cg.currentMaxAutoGain, currentModeMeanSetting) + 1;
		currentModeMeanSetting.exposureLevelMin = calcExposureLevel(minExposure_us, minGain, currentModeMeanSetting) - 1;
	}
	else if (currentModeMeanSetting.meanAuto == MEAN_AUTO_GAIN_ONLY) {
		currentModeMeanSetting.exposureLevelMax = calcExposureLevel(cg.currentMaxAutoExposure_us, cg.currentMaxAutoGain, currentModeMeanSetting) + 1;
		currentModeMeanSetting.exposureLevelMin = calcExposureLevel(cg.currentMaxAutoExposure_us, minGain, currentModeMeanSetting) - 1;
	}
	else if (currentModeMeanSetting.meanAuto == MEAN_AUTO_EXPOSURE_ONLY) {
		currentModeMeanSetting.exposureLevelMax = calcExposureLevel(cg.currentMaxAutoExposure_us, cg.currentMaxAutoGain, currentModeMeanSetting) + 1;
		currentModeMeanSetting.exposureLevelMin = calcExposureLevel(minExposure_us, cg.currentMaxAutoGain, currentModeMeanSetting) - 1;
	}
	else if (currentModeMeanSetting.meanAuto == MEAN_AUTO_OFF) {
		// xxxx Do we need to set these?  Are they even used in MEAN_AUTO_OFF mode?
		currentModeMeanSetting.exposureLevelMax = calcExposureLevel(cg.currentMaxAutoExposure_us, cg.currentMaxAutoGain, currentModeMeanSetting) + 1;
		currentModeMeanSetting.exposureLevelMin = calcExposureLevel(cg.currentMaxAutoExposure_us, cg.currentMaxAutoGain, currentModeMeanSetting) - 1;
	}
	currentModeMeanSetting.minExposure_us = minExposure_us;
	currentModeMeanSetting.maxExposure_us = cg.currentMaxAutoExposure_us;
	currentModeMeanSetting.minGain = minGain;
	currentModeMeanSetting.maxGain = cg.currentMaxAutoGain;

	Log(3, "  > Valid exposureLevels: %'1.3f to %'1.3f\n", currentModeMeanSetting.exposureLevelMin, currentModeMeanSetting.exposureLevelMax);
	Log(3, "  > Starting:   exposure: %s, gain: %1.3f, exposure level: %d\n", length_in_units(cg.currentExposure_us, true), cg.currentGain, initialExposureLevel);

	return true;
}


// Calculate mean of current image.
float aegCalcMean(cv::Mat image)
{
	float mean;

	// Only create the destination image and mask the first time we're called.
	static cv::Mat mask;
	static bool maskCreated = false;
	if (! maskCreated)
	{
		maskCreated = true;

// TODO: Allow user to specify a mask file
		// Create a circular mask at the center of the image with a radius of 1/3 the height of the image.
		cv::Mat mask = cv::Mat::zeros(image.size(), CV_8U);		// should CV_8U be image.type() ?
		cv::circle(mask, cv::Point(mask.cols/2, mask.rows/2), mask.rows/3, cv::Scalar(255, 255, 255), -1, 8, 0);

		// Copy the source image to destination image with masking.
		cv::Mat dstImage = cv::Mat::zeros(image.size(), CV_8U);
		image.copyTo(dstImage, mask);

#ifdef xxxxxxxx_for_testing
	bool result;
	std::vector<int> compressionParameters;
	compressionParameters.push_back(cv::IMWRITE_JPEG_QUALITY);
	compressionParameters.push_back(95);
	char const *dstImageName = "dstImage.jpg";
	result = cv::imwrite(dstImageName, dstImage, compressionParameters);
	if (! result) fprintf(stderr, "*** ERROR: Unable to write to '%s'\n", dstImageName);
	char const *maskName = "mask.jpg";
	result = cv::imwrite(maskName, mask, compressionParameters);
	if (! result) fprintf(stderr, "*** ERROR: Unable to write to '%s'\n", maskName);
#endif

	}

	cv::Scalar mean_scalar = cv::mean(image, mask);
	switch (image.channels())
	{
		default: // mono case
			mean = mean_scalar.val[0];
			break;
		case 3: // for color use average of the channels
		case 4:
			mean = (mean_scalar[0] + mean_scalar[1] + mean_scalar[2]) / 3.0;
			break;
	}
	// Scale to 0-1 range
	switch (image.depth())
	{
		case CV_8U:
			mean /= 255.0;
			break;
		case CV_16U:
			mean /= 65535.0;
			break;
	}

	return(mean);	// return this image's mean
}


// Calculate the new exposure and gain values.
void aegGetNextExposureSettings(float prevMean, int exposure_us, double gain,
		raspistillSetting & currentRaspistillSetting,
		modeMeanSetting & currentModeMeanSetting)
{
	double mean_diff;
	double max_;			// calculate std::max() by itself to make the code easier to read.
	// get old exposureTime_s in seconds
	double exposureTime_s = (double) currentRaspistillSetting.shutter_us/(double)US_IN_SEC;

	static int values = 0;
	// "values" will always be the same value for every image so only calculate once.
	// If historySize is 3:
	// i=1 (0+1==1), i=2 (2+1==3), i=3 (3+3==6).  6 += 3 == 9
	if (values == 0) {
		for (int i=1; i <= currentModeMeanSetting.historySize; i++)
			values += i;
		values += currentModeMeanSetting.historySize;
	}

	Log(3, "  > Just got:    shutter_us: %s, mean: %1.3f, target mean: %1.3f, diff (target - mean): %'1.3f, MeanCnt: %d, values: %d\n",
		length_in_units(currentRaspistillSetting.shutter_us, true), prevMean,
		currentModeMeanSetting.meanValue, (currentModeMeanSetting.meanValue - prevMean), MeanCnt, values);

	meanHistory[MeanCnt % currentModeMeanSetting.historySize] = prevMean;

	int idx = (MeanCnt + currentModeMeanSetting.historySize) % currentModeMeanSetting.historySize;
	int idxN1 = (MeanCnt + currentModeMeanSetting.historySize-1) % currentModeMeanSetting.historySize;

	dMean = meanHistory[idx] - meanHistory[idxN1];
	dExp = exposureLevelHistory[idx] - exposureLevelHistory[idxN1];

	// mean_forcast = m_new + diff = m_new + (m_new - m_previous) = (2 * m_new) - m_previous
	// If the previous mean was more than twice as large as the current one, mean_forecast will be negative.
	double mean_forecast = (2.0 * meanHistory[idx]) - meanHistory[idxN1];	// "2.0 *" gives more weight to the current mean
	max_ = std::max(mean_forecast, 0.0);
	mean_forecast = std::min(max_, currentModeMeanSetting.minGain);
	// gleiche Wertigkeit wie aktueller Wert

	// avg of mean history
	double newMean = 0.0;
	for (int i=1; i <= currentModeMeanSetting.historySize; i++) {
		int ii =  (MeanCnt + i) % currentModeMeanSetting.historySize;
		newMean += meanHistory[ii] * (double) i;		// This gives more weight to means later in the history array.
		Log(4, "  > index: %d, meanHistory[]=%1.3f exposureLevelHistory[]=%d, newNean=%1.3f\n", ii, meanHistory[ii], exposureLevelHistory[ii], newMean);
	}
	newMean += mean_forecast * currentModeMeanSetting.historySize;
	newMean /= (double) values;
	mean_diff = abs(newMean - currentModeMeanSetting.meanValue);
	Log(3, "  > New mean: %1.3f, mean_forecast: %1.3f, mean_diff (newMean - target mean): %'1.3f, idx=%d, idxN1=%d\n", newMean, mean_forecast, mean_diff, idx, idxN1);

	int ExposureChange;

	// fast forward
	if (fastforward || mean_diff > (currentModeMeanSetting.mean_threshold * 2.0)) {
		// We are fairly far off from desired mean.
		ExposureChange = std::max(1.0, currentModeMeanSetting.mean_p0 + (currentModeMeanSetting.mean_p1 * mean_diff) + pow(currentModeMeanSetting.mean_p2 * mean_diff, 2.0));
		Log(3, "  > fast forward ExposureChange now %d (mean_diff=%1.3f > 2*threshold=%1.3f)\n", ExposureChange, mean_diff, currentModeMeanSetting.mean_threshold*2.0);
	}
	// slow forward
	else if (mean_diff > currentModeMeanSetting.mean_threshold) {
		// We are fairly close to desired mean.
		ExposureChange = std::max(1.0, currentModeMeanSetting.mean_p0 + currentModeMeanSetting.mean_p1 * mean_diff);
		Log(3, "  > slow forward ExposureChange now %d (mean_diff=%1.3f, threshold=%1.3f)\n", ExposureChange, mean_diff, currentModeMeanSetting.mean_threshold);
	}
	else {
		ExposureChange = currentModeMeanSetting.shuttersteps / 2;
	}

	int const maxChange = 75;		// xxxxx for testing: s/50/75/
	ExposureChange = std::min(maxChange, ExposureChange);			// limit how big of a change we make each time
	dExposureChange = ExposureChange - lastExposureChange;
	lastExposureChange = ExposureChange;

	Log(4, "  > ExposureChange clipped to %d (diff from last change: %d)\n", ExposureChange, dExposureChange);

	// If the last image's mean was good, no changes are needed to the next one.
	bool goodLastExposure = true;
// TODO: make mean_threshold a percent instead of an actual value.  This will allow us to use 0 to 100 for what user enters as mean.

	if (prevMean < (currentModeMeanSetting.meanValue - currentModeMeanSetting.mean_threshold)) {
		// mean too low
		if ((currentRaspistillSetting.analoggain < currentModeMeanSetting.maxGain) || (currentRaspistillSetting.shutter_us < currentModeMeanSetting.maxExposure_us)) {  // obere Grenze durch Gain und shutter
			goodLastExposure = false;
			currentModeMeanSetting.exposureLevel += ExposureChange;
			Log(4, "  >> exposureLevel increased by %d to %d\n", ExposureChange, currentModeMeanSetting.exposureLevel);
		}
		else {
			Log(3, "  >> Already at max gain (%1.3f) and/or max exposure (%s) - can't go any higher!\n", currentModeMeanSetting.maxGain, length_in_units(currentModeMeanSetting.maxExposure_us, true));
		}
	}
	else if (prevMean > (currentModeMeanSetting.meanValue + currentModeMeanSetting.mean_threshold))  {
		// mean too high
/// xxxxxxx how about minGain?
		if (exposureTime_s > currentModeMeanSetting.minExposure_us / (double)US_IN_SEC) { // untere Grenze durch shuttertime
			goodLastExposure = false;
			currentModeMeanSetting.exposureLevel -= ExposureChange;
			Log(4, "  > exposureLevel decreased by %d to %d\n", ExposureChange, currentModeMeanSetting.exposureLevel);
		}
		else {
			Log(3, "  >> Already at min exposure (%'d us) - can't go any lower!\n", currentModeMeanSetting.minExposure_us);
		}
	}
	else {
		Log(3, "  >> Prior image mean good - no changes needed, mean=%1.3f, target mean=%1.3f threshold=%1.3f +++++++++\n", prevMean, currentModeMeanSetting.meanValue, currentModeMeanSetting.mean_threshold);
		if (currentModeMeanSetting.quickstart > 0)
		{
			currentModeMeanSetting.quickstart = 0;		// Got a good exposure - turn quickstart off if on
			Log(4, "  >> Disabling quickstart\n");
		}
	}

	// Make sure exposureLevel is within min - max range.
	max_ = std::max(currentModeMeanSetting.exposureLevel, (int)currentModeMeanSetting.exposureLevelMin);
	currentModeMeanSetting.exposureLevel = std::min((int)max_, (int)currentModeMeanSetting.exposureLevelMax);
	double exposureTimeEff_s = calcExposureTimeEff(currentModeMeanSetting.exposureLevel, currentModeMeanSetting);

	// fastforward ?
	if ((currentModeMeanSetting.exposureLevel == (int)currentModeMeanSetting.exposureLevelMax) || (currentModeMeanSetting.exposureLevel == (int)currentModeMeanSetting.exposureLevelMin)) {
		fastforward = true;
		Log(4, "  > FF activated\n");
	}
	if (fastforward &&
		(abs(meanHistory[idx] - currentModeMeanSetting.meanValue) < currentModeMeanSetting.mean_threshold) &&
		(abs(meanHistory[idxN1] - currentModeMeanSetting.meanValue) < currentModeMeanSetting.mean_threshold)) {
printf(">>>>>>>>> fastforward=%s\n", fastforward ? "true" : "false");
		fastforward = false;
		Log(4, "  > FF deactivated\n");
	}

	//########################################################################
	// calculate new gain
	if (! goodLastExposure)
	{

// xxxx TODO:  when INCREASING the mean, the gain goes to the max before the exposure increases.
// It should increase exposure, then gain, then exposure, ...

		if (currentModeMeanSetting.meanAuto == MEAN_AUTO || currentModeMeanSetting.meanAuto == MEAN_AUTO_GAIN_ONLY) {
// xxxxxxx ??? "exposure_us" or maxExposure_us or exposureTime_s ?
			max_ = std::max(currentModeMeanSetting.minGain, exposureTimeEff_s / (exposure_us/(double)US_IN_SEC));
			// xxxx  double newGain = std::min(gain, max_);
			double newGain = std::min(currentModeMeanSetting.maxGain, max_);
			if (newGain > currentModeMeanSetting.maxGain) {
				currentRaspistillSetting.analoggain = currentModeMeanSetting.maxGain;
				Log(3, "  >> Setting new analoggain to %1.3f (max value) (newGain was %1.3f)\n", currentRaspistillSetting.analoggain, newGain);
			}
			else if (newGain < currentModeMeanSetting.minGain) {
				currentRaspistillSetting.analoggain = currentModeMeanSetting.minGain;
				Log(3, "  >> Setting new analoggain to %1.3f (min value) (newGain was %1.3f)\n", currentRaspistillSetting.analoggain, newGain);
			}
			else if (currentRaspistillSetting.analoggain != newGain) {
				currentRaspistillSetting.analoggain = newGain;
				Log(3, "  >> Setting new analoggain to %1.3f\n", newGain);
			}
			else {
				char const *isWhat = ((newGain == currentModeMeanSetting.minGain) || (newGain == currentModeMeanSetting.maxGain)) ? "possible" : "needed";
				Log(3, "  >> No change to analoggain is %s (is %1.3f) +++\n", isWhat, newGain);
			}
		}
		else if (currentRaspistillSetting.analoggain != gain) {
			// it should already be at "gain", but just in case, set it anyhow
			currentRaspistillSetting.analoggain = gain;
			Log(3, "  >> setting new gain to %1.3f\n", gain);
		}
 
		// calculate new exposure time based on the (possibly) new gain
		if (currentModeMeanSetting.meanAuto == MEAN_AUTO || currentModeMeanSetting.meanAuto == MEAN_AUTO_EXPOSURE_ONLY) {
			max_ = std::max((double)currentModeMeanSetting.minExposure_us / (double)US_IN_SEC, exposureTimeEff_s / currentRaspistillSetting.analoggain);
			double eOLD_s = exposureTime_s * US_IN_SEC;
			double eNEW_s = std::min((double)currentModeMeanSetting.maxExposure_us / (double)US_IN_SEC, max_);
			if (exposureTime_s == eNEW_s) {
				Log(3, "  >> No change to exposure time needed +++\n");
			}
			else {
				Log(3, "  >> Setting new exposureTime_s to %s ", length_in_units((long)(eNEW_s * US_IN_SEC), true));
				Log(3, "(was %s: ", length_in_units(eOLD_s, true));
				Log(3, "diff %s)\n", length_in_units((eNEW_s-exposureTime_s) * US_IN_SEC, true));
				exposureTime_s = eNEW_s;
			}
		}
		else if (0 && currentModeMeanSetting.meanAuto == MEAN_AUTO_EXPOSURE_ONLY) {		// xxxxx don't use
			max_ = std::max((double)currentModeMeanSetting.minExposure_us / (double)US_IN_SEC, exposureTimeEff_s / currentRaspistillSetting.analoggain);
			exposureTime_s = std::min((double)currentModeMeanSetting.maxExposure_us / (double)US_IN_SEC, max_);
		}
		else { // MEAN_AUTO_GAIN_ONLY || MEAN_AUTO_OFF
			// exposureTime_s = (double)exposure_us/(double)US_IN_SEC;		// leave exposure alone
		}
	}

	//#############################################################################################################
	// prepare for the next measurement
	if (currentModeMeanSetting.quickstart > 0) {
		currentModeMeanSetting.quickstart--;
	}
	// Exposure gilt fuer die naechste Messung
	MeanCnt++;
	exposureLevelHistory[MeanCnt % currentModeMeanSetting.historySize] = currentModeMeanSetting.exposureLevel;

	currentRaspistillSetting.shutter_us = exposureTime_s * (double)US_IN_SEC;
	Log(3, "  > Next image:  mean: %'1.3f (diff from target: %'1.3f), Exposure level: %'d (minus %d: %d), Exposure time: %s, gain: %1.2f\n",
		newMean, mean_diff,
		currentModeMeanSetting.exposureLevel,
		exposureLevelHistory[idx], currentModeMeanSetting.exposureLevel - exposureLevelHistory[idx],
		length_in_units(currentRaspistillSetting.shutter_us, true), currentRaspistillSetting.analoggain);
}