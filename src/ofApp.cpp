#include "ofApp.h"

//--------------------------------------------------------------
void ofApp::setup()
{
    ofSetFrameRate(1000);
    ofTrueTypeFont::setGlobalDpi(72);

    string path = "/Users/moritzsalla/Library/Fonts/";
    ofDirectory dir(path);
    dir.allowExt("ttf");
    dir.listDir();
    string filePath;
    fontPaths[dir.size()];

    // ofLog() << dir.size();

    for (int i = 0; i < dir.size(); i++)
    {
        fontPaths[i] = dir.getPath(i), 14, true, true;
    }

    font.setLineHeight(0.0f);
    ofSetBackgroundColor(0);
    ofSetColor(255);
}

//--------------------------------------------------------------
void ofApp::update()
{
    if (ofGetFrameNum() == 2805)
    {
        ofExit();
    }

    ofSaveScreen("a/" + ofToString(ofGetFrameNum()) + "-ttf.jpg");
}

//--------------------------------------------------------------
void ofApp::draw()
{
    ofSetBackgroundColor(0);
    ofSetColor(255);

    try
    {
        font.load(fontPaths[ofGetFrameNum()], 60, false);
        font.drawString("a", 15, ofGetHeight() - 10);
    }
    catch (...)
    {
        ofLog() << "error loading font";
    }
}

//--------------------------------------------------------------
void ofApp::keyPressed(int key)
{
}

//--------------------------------------------------------------
void ofApp::keyReleased(int key)
{
}

//--------------------------------------------------------------
void ofApp::mouseMoved(int x, int y)
{
}

//--------------------------------------------------------------
void ofApp::mouseDragged(int x, int y, int button)
{
}

//--------------------------------------------------------------
void ofApp::mousePressed(int x, int y, int button)
{
}

//--------------------------------------------------------------
void ofApp::mouseReleased(int x, int y, int button)
{
}

//--------------------------------------------------------------
void ofApp::mouseEntered(int x, int y)
{
}

//--------------------------------------------------------------
void ofApp::mouseExited(int x, int y)
{
}

//--------------------------------------------------------------
void ofApp::windowResized(int w, int h)
{
}

//--------------------------------------------------------------
void ofApp::gotMessage(ofMessage msg)
{
}

//--------------------------------------------------------------
void ofApp::dragEvent(ofDragInfo dragInfo)
{
}
