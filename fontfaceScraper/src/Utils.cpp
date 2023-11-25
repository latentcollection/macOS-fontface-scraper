#include "ofMain.h"
#include "Constants.h"
#include "Utils.h"

ofDirectory Utils::getFontDirectory() {
	ofDirectory dir(Constants::FONT_DIR);
	dir.allowExt(Constants::FONT_TYPE);
	dir.listDir();

	return dir;
}
