#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <string>
#include <vector>

namespace TextUtil {

std::string fromCFString(CFStringRef s);
std::vector<UniChar> toUTF16(const std::string &utf8);

std::string expandTilde(const std::string &path);

// Replaces path separators and control characters, and any leading dot that
// would otherwise make the file hidden.
std::string sanitizeFilename(const std::string &in);

std::vector<std::string> splitOnCommas(const std::string &in);

// Without commas every character is its own glyph, so "abc" means three glyphs.
// Commas are the escape hatch for entries longer than one character.
std::vector<std::string> parseGlyphList(const std::string &in);

std::string csvEscape(const std::string &in);

// Renders a FourCharCode such as 'wght' as text, substituting unprintables.
std::string fourCharCode(uint32_t tag);

}  // namespace TextUtil
