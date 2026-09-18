#pragma once

#include <CoreText/CoreText.h>
#include <string>
#include <vector>

#include "Options.h"

namespace GlyphRenderer {

// Rasterizes one face's glyphs to a square grayscale PNG. Returns false when
// the glyphs carry no ink, which covers whitespace and faces that map the
// character to an empty outline.
bool renderToPNG(CTFontRef font,
                 const std::vector<CGGlyph> &glyphs,
                 const Options &opt,
                 int canvas,
                 const std::string &outPath);

}  // namespace GlyphRenderer
