#pragma once

#include <CoreGraphics/CoreGraphics.h>
#include <string>
#include <vector>

// How a glyph is scaled and positioned on the canvas.
enum class FitMode {
    Fit,      // scale each glyph's ink to fill the canvas
    Metric,   // fixed point size on a shared baseline
    XHeight,  // scale so x-height matches, leaving width and weight as signal
};

namespace Layout {

// Glyphs are laid out in this coordinate space and then scaled to whatever
// --size asks for, so a size sweep produces one picture at several resolutions
// rather than several different croppings.
const CGFloat kReferenceCanvas = 256.0;

// Default share of the canvas taken by one x-height in xheight mode. Low enough
// to leave room for ascenders and descenders on most faces; raise it with
// --xheight when the glyph set has neither.
const CGFloat kDefaultXHeightTarget = 0.34;

// Across most Latin typefaces the x-height lands near 70% of the cap height.
// Only used as a fallback for faces that report no x-height at all.
const CGFloat kXHeightPerCapHeight = 0.70;

const CGFloat kDefaultMargin = 0.10;
const char *const kDefaultGlyph = "a";
const CGFloat kDefaultPointSize = 200.0;

}  // namespace Layout

namespace Limits {

// Below 8px a glyph is indistinguishable from noise; above 4096 a full scrape
// would exhaust memory long before it finished.
const int kMinCanvas = 8;
const int kMaxCanvas = 4096;
const int kDefaultCanvas = 256;

// A margin of half the canvas leaves nothing to draw into.
const double kMaxMargin = 0.5;

const int kMinVariations = 1;
const int kMaxVariations = 64;

// Longest font directory path accepted at the interactive prompt.
const size_t kMaxPathInput = 4096;

}  // namespace Limits

struct Options {
    std::vector<std::string> fontDirs;
    std::vector<std::string> glyphs = {Layout::kDefaultGlyph};
    std::vector<int>         sizes  = {Limits::kDefaultCanvas};

    bool        glyphSubdirs   = false;  // set by --glyphs, not --glyph
    bool        sizeSubdirs    = false;  // set by --sizes, not --size

    FitMode     mode           = FitMode::Fit;
    double      pointSize      = Layout::kDefaultPointSize;      // metric mode only
    double      margin         = Layout::kDefaultMargin;         // fraction of canvas
    double      xHeightTarget  = Layout::kDefaultXHeightTarget;  // xheight mode only

    std::string outDir         = "out";
    long        limit          = 0;  // images per glyph, 0 = no cap
    long        perFamily      = 0;  // faces per family, 0 = no cap
    int         variations     = 1;  // instances sampled per variable font

    bool        invert         = false;
    bool        listOnly       = false;
    bool        assumeYes      = false;
    bool        includePrivate = false;
    bool        manifest       = false;
    std::string licenseFilter;  // keep only faces whose license text or URL matches
};
