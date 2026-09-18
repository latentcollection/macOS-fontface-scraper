#pragma once

#include <string>

#include "FontCatalog.h"

// Accumulates one CSV row per written image, describing the face it came from.
// Enough to condition a model on style rather than only on which letter it is.
class Manifest {
public:
    void add(const FontCatalog::Job &job, const std::string &relativePath,
             const std::string &glyph, int size);

    bool writeTo(const std::string &path) const;

    bool empty() const { return rows_.empty(); }

private:
    std::string rows_;
};
