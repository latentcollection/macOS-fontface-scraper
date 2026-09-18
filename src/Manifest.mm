#include "Manifest.h"
#include "TextUtil.h"

#include <cmath>
#include <cstdio>

namespace {

const char *kHeader =
    "file,postscript_name,family,glyph,size,weight,width,slant,class,"
    "italic,bold,condensed,expanded,monospace,axis,axis_value,"
    "license,license_url,copyright,vendor\n";

const char *kFlag[] = {"0", "1"};

// Three %.4f values and their separators.
const size_t kMetricsBufferSize = 64;

}  // namespace

void Manifest::add(const FontCatalog::Job &job, const std::string &relativePath,
                   const std::string &glyph, int size) {
    const FontCatalog::Traits &t = job.traits;

    char metrics[kMetricsBufferSize];
    snprintf(metrics, sizeof metrics, "%.4f,%.4f,%.4f", t.weight, t.width, t.slant);

    rows_ += TextUtil::csvEscape(relativePath) + "," +
             TextUtil::csvEscape(job.name) + "," +
             TextUtil::csvEscape(job.family) + "," +
             TextUtil::csvEscape(glyph) + "," +
             std::to_string(size) + "," +
             metrics + "," +
             t.klass + "," +
             kFlag[t.italic] + "," + kFlag[t.bold] + "," + kFlag[t.condensed] + "," +
             kFlag[t.expanded] + "," + kFlag[t.mono] + "," +
             TextUtil::csvEscape(job.axis) + "," +
             (job.axis.empty() ? "" : std::to_string((long)llround(job.axisValue))) + "," +
             TextUtil::csvEscape(job.license.terms) + "," +
             TextUtil::csvEscape(job.license.url) + "," +
             TextUtil::csvEscape(job.license.copyright) + "," +
             TextUtil::csvEscape(job.license.vendor) +
             "\n";
}

bool Manifest::writeTo(const std::string &path) const {
    FILE *f = fopen(path.c_str(), "w");
    if (!f) return false;
    fputs(kHeader, f);
    fwrite(rows_.data(), 1, rows_.size(), f);
    fclose(f);
    return true;
}
