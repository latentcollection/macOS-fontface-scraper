#include "ofMain.h"
#include "ofApp.h"
#include "Constants.h"

int main()
{
	ofSetupOpenGL(Constants::SIZE, Constants::SIZE, OF_WINDOW);
	ofRunApp(new ofApp());
}
