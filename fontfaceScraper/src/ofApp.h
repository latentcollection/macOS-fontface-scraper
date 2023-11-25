#pragma once

#include "ofMain.h"

class ofApp : public ofBaseApp {
public:
	void setup();
	void update();
	void draw();
	
	ofTrueTypeFont font;
	std::vector<std::string> fontPaths;
};
