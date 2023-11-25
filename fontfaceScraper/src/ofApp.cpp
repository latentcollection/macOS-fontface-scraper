#include "ofApp.h"
#include "Constants.h"
#include "Utils.h"

void ofApp::setup()
{
	// Set render defaults
	ofSetFrameRate(Constants::FRAME_RATE);
	ofTrueTypeFont::setGlobalDpi(Constants::DPI);
	
	// Setup font dir
	ofDirectory dir = Utils::getFontDirectory();
	dir.allowExt(Constants::FONT_TYPE);
	dir.listDir();
	
	// Initialize fontPaths array
	fontPaths.resize(dir.size());
	
	// Loop over fonts and extract paths
	for (int i = 0; i < dir.size(); i++)
	{
		fontPaths[i] = dir.getPath(i);
	}
	
	font.setLineHeight(0.0f);
	ofSetBackgroundColor(Constants::BACKGROUND_COLOR);
	ofSetColor(Constants::TEXT_COLOR);
	
	// Inform the user about the setup completion
	ofLog() << "Setup completed successfully. Found " << dir.size() << " " << Constants::FONT_TYPE + " fonts.";
}

void ofApp::update()
{
	int currentFrameNum = ofGetFrameNum();
	
	ofDirectory dir = Utils::getFontDirectory();
	int inputDirSize = dir.size();
	bool haveAllFontsBeenRendered = currentFrameNum == inputDirSize;
	bool hasFrameCapBeenReached = currentFrameNum == Constants::MAX_OUTPUT;
	
	// When all fonts have been rendered or max frames reached, quit.
	if (haveAllFontsBeenRendered || hasFrameCapBeenReached)
	{
		// Inform the user about the completion and the number of images generated
		ofLog() << "Done. Generated " << currentFrameNum << " images from " << inputDirSize << " font files.";
		ofExit();
	}
	
	
	std::string filePath = Constants::FONT_TYPE + "/" + Constants::GLYPH + "/" + std::to_string(currentFrameNum) + ".jpg";
	ofSaveScreen(filePath);
	
}

void ofApp::draw()
{
	// Set background color and text color
	ofSetBackgroundColor(Constants::BACKGROUND_COLOR);
	ofSetColor(Constants::TEXT_COLOR);
	
	try
	{
		font.load(fontPaths[ofGetFrameNum()], Constants::TEXT_SIZE, false);
		font.drawString(Constants::GLYPH, Constants::TEXT_SIZE, ofGetHeight() - 10);
	}
	catch (...)
	{
		ofLog() << "Error loading font. Check your configuration.";
	}
}

