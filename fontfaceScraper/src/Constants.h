#pragma once

namespace Constants {
// Environment
const string USER_DIR = ofFilePath::getUserHomeDir();
const string FONT_DIR = USER_DIR + "/Library/Fonts/";

// Render output
const string FONT_TYPE = "ttf"; // ttf, otf, ...
const int SIZE = 64;
const int DPI = 64;
const int FRAME_RATE = 30;

// Appearance
const string GLYPH = "a";
const int TEXT_SIZE = 40;

const int BACKGROUND_COLOR = 0;
const int TEXT_COLOR = 255;

// Maximum frames outputted
const int MAX_OUTPUT = 2805;
}
