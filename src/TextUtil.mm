#import <Foundation/Foundation.h>

#include "TextUtil.h"

#include <algorithm>

namespace TextUtil {
namespace {

const unsigned char kFirstPrintableASCII = 0x20;
const unsigned char kLastPrintableASCII  = 0x7E;

// Leading bits that mark the start of a multi-byte UTF-8 sequence.
const unsigned char kUTF8FourByteMask = 0xF8, kUTF8FourByteLead = 0xF0;
const unsigned char kUTF8ThreeByteMask = 0xF0, kUTF8ThreeByteLead = 0xE0;
const unsigned char kUTF8TwoByteMask = 0xE0, kUTF8TwoByteLead = 0xC0;

}  // namespace

std::string fromCFString(CFStringRef s) {
    if (!s) return {};
    CFIndex maxLen = CFStringGetMaximumSizeForEncoding(CFStringGetLength(s),
                                                       kCFStringEncodingUTF8) + 1;
    std::string buf(static_cast<size_t>(maxLen), '\0');
    if (!CFStringGetCString(s, buf.data(), maxLen, kCFStringEncodingUTF8)) return {};
    buf.resize(strlen(buf.c_str()));
    return buf;
}

std::vector<UniChar> toUTF16(const std::string &utf8) {
    std::vector<UniChar> out;
    CFStringRef s = CFStringCreateWithBytes(nullptr,
                                            reinterpret_cast<const UInt8 *>(utf8.data()),
                                            static_cast<CFIndex>(utf8.size()),
                                            kCFStringEncodingUTF8, false);
    if (!s) return out;
    CFIndex len = CFStringGetLength(s);
    out.resize(static_cast<size_t>(len));
    if (len > 0) CFStringGetCharacters(s, CFRangeMake(0, len), out.data());
    CFRelease(s);
    return out;
}

std::string expandTilde(const std::string &path) {
    if (path.empty() || path[0] != '~') return path;
    NSString *s = [[NSString stringWithUTF8String:path.c_str()] stringByExpandingTildeInPath];
    return s ? std::string(s.UTF8String) : path;
}

std::string sanitizeFilename(const std::string &in) {
    std::string out;
    out.reserve(in.size());
    for (unsigned char c : in) {
        bool unsafe = c < kFirstPrintableASCII || c == '/' || c == ':' || c == '\\';
        out.push_back(unsafe ? '_' : static_cast<char>(c));
    }
    if (!out.empty() && out[0] == '.') out[0] = '_';
    return out.empty() ? "unnamed" : out;
}

std::vector<std::string> splitOnCommas(const std::string &in) {
    std::vector<std::string> out;
    size_t start = 0;
    while (start <= in.size()) {
        size_t comma = in.find(',', start);
        if (comma == std::string::npos) comma = in.size();
        std::string piece = in.substr(start, comma - start);
        size_t a = piece.find_first_not_of(" \t");
        size_t b = piece.find_last_not_of(" \t");
        if (a != std::string::npos) out.push_back(piece.substr(a, b - a + 1));
        start = comma + 1;
    }
    return out;
}

std::vector<std::string> parseGlyphList(const std::string &in) {
    if (in.find(',') != std::string::npos) return splitOnCommas(in);

    std::vector<std::string> out;
    size_t i = 0;
    while (i < in.size()) {
        size_t len = 1;
        unsigned char c = in[i];
        if      ((c & kUTF8FourByteMask)  == kUTF8FourByteLead)  len = 4;
        else if ((c & kUTF8ThreeByteMask) == kUTF8ThreeByteLead) len = 3;
        else if ((c & kUTF8TwoByteMask)   == kUTF8TwoByteLead)   len = 2;
        len = std::min(len, in.size() - i);
        out.push_back(in.substr(i, len));
        i += len;
    }
    return out;
}

std::string csvEscape(const std::string &in) {
    if (in.find_first_of(",\"\n") == std::string::npos) return in;
    std::string out = "\"";
    for (char c : in) { out += c; if (c == '"') out += '"'; }
    return out + "\"";
}

std::string fourCharCode(uint32_t tag) {
    const int kChars = 4, kBitsPerChar = 8;
    std::string s(kChars, '_');
    for (int i = 0; i < kChars; i++) {
        char c = static_cast<char>((tag >> ((kChars - 1 - i) * kBitsPerChar)) & 0xFF);
        s[i] = (c >= (char)kFirstPrintableASCII && c <= (char)kLastPrintableASCII) ? c : '_';
    }
    return s;
}

}  // namespace TextUtil
