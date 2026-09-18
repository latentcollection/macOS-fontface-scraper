#pragma once

#include <CoreText/CoreText.h>
#include <string>
#include <vector>

#include "Options.h"

namespace FontCatalog {

// The weight axis of a variable font, preferred over other axes when sampling.
const uint32_t kWeightAxisTag = 'wght';

// Core Text's own classification of a face, which is more dependable than
// guessing from the name and is the sort of label worth conditioning a model on.
struct Traits {
    double weight = 0, width = 0, slant = 0;
    bool italic = false, bold = false, condensed = false, expanded = false, mono = false;
    std::string klass = "unknown";
};

// What the font itself claims about its terms. Read straight from the OpenType
// name table, so it is the vendor's own text rather than anything inferred.
// Most libre fonts fill in the license fields; most commercial ones leave them
// empty and put their terms in a separate agreement.
struct License {
    std::string terms;      // name ID 13, the license description
    std::string url;        // name ID 14
    std::string copyright;
    std::string vendor;
};

// One image to render: a face (possibly a variable-font instance) and the glyph
// ids it resolved the requested characters to.
struct Job {
    CTFontDescriptorRef desc = nullptr;  // owned, always +1
    std::string name;                    // PostScript name, also the file stem
    std::string family;
    std::string axis;                    // variation axis tag, empty when not an instance
    double axisValue = 0;
    Traits traits;
    License license;
    std::vector<CGGlyph> glyphs;
};

struct Tally {
    long noGlyph = 0, duplicates = 0, privateFaces = 0, unreadable = 0,
         familyCapped = 0, licenseFiltered = 0;
};

// Every face under the given directories, recursively. Caller releases each.
std::vector<CTFontDescriptorRef> descriptorsInDirectories(const std::vector<std::string> &dirs);

// Resolves glyph ids, drops faces that can't render the characters, expands
// variable fonts and applies the per-family and overall caps. Glyph ids don't
// depend on point size, so one call serves every size in a sweep.
// Caller releases each job's descriptor.
std::vector<Job> buildJobs(const std::vector<CTFontDescriptorRef> &descriptors,
                           const std::vector<UniChar> &chars,
                           const Options &opt,
                           CGFloat renderSize,
                           Tally *tally);

void releaseJobs(std::vector<Job> &jobs);

}  // namespace FontCatalog
