#import <Foundation/Foundation.h>

#include "FontCatalog.h"
#include "TextUtil.h"

#include <algorithm>
#include <cmath>
#include <map>
#include <unordered_set>

namespace FontCatalog {
namespace {

bool isFontFile(NSString *path) {
    NSString *ext = path.pathExtension.lowercaseString;
    return [ext isEqualToString:@"ttf"]  || [ext isEqualToString:@"otf"] ||
           [ext isEqualToString:@"ttc"]  || [ext isEqualToString:@"otc"] ||
           [ext isEqualToString:@"dfont"];
}

std::string copyStringAttribute(CTFontDescriptorRef desc, CFStringRef key) {
    CFStringRef s = (CFStringRef)CTFontDescriptorCopyAttribute(desc, key);
    std::string result = TextUtil::fromCFString(s);
    if (s) CFRelease(s);
    return result;
}

std::string stylisticClassName(CTFontSymbolicTraits sym) {
    switch (sym & kCTFontTraitClassMask) {
        case kCTFontClassOldStyleSerifs:     return "oldstyle-serif";
        case kCTFontClassTransitionalSerifs: return "transitional-serif";
        case kCTFontClassModernSerifs:       return "modern-serif";
        case kCTFontClassClarendonSerifs:    return "clarendon-serif";
        case kCTFontClassSlabSerifs:         return "slab-serif";
        case kCTFontClassFreeformSerifs:     return "freeform-serif";
        case kCTFontClassSansSerif:          return "sans-serif";
        case kCTFontClassOrnamentals:        return "ornamental";
        case kCTFontClassScripts:            return "script";
        case kCTFontClassSymbolic:           return "symbolic";
        default:                             return "unknown";
    }
}

Traits readTraits(CTFontDescriptorRef desc) {
    Traits t;
    CFDictionaryRef d = (CFDictionaryRef)CTFontDescriptorCopyAttribute(desc, kCTFontTraitsAttribute);
    if (!d) return t;

    auto number = [&](CFStringRef key, double *out) {
        CFNumberRef n = (CFNumberRef)CFDictionaryGetValue(d, key);
        if (n) CFNumberGetValue(n, kCFNumberDoubleType, out);
    };
    number(kCTFontWeightTrait, &t.weight);
    number(kCTFontWidthTrait,  &t.width);
    number(kCTFontSlantTrait,  &t.slant);

    CFNumberRef symRef = (CFNumberRef)CFDictionaryGetValue(d, kCTFontSymbolicTrait);
    if (symRef) {
        uint32_t sym = 0;
        CFNumberGetValue(symRef, kCFNumberSInt32Type, &sym);
        t.italic    = sym & kCTFontTraitItalic;
        t.bold      = sym & kCTFontTraitBold;
        t.condensed = sym & kCTFontTraitCondensed;
        t.expanded  = sym & kCTFontTraitExpanded;
        t.mono      = sym & kCTFontTraitMonoSpace;
        t.klass     = stylisticClassName((CTFontSymbolicTraits)sym);
    }
    CFRelease(d);
    return t;
}

std::string copyFontName(CTFontRef font, CFStringRef key) {
    CFStringRef s = CTFontCopyName(font, key);
    std::string result = TextUtil::fromCFString(s);
    if (s) CFRelease(s);
    return result;
}

License readLicense(CTFontRef font) {
    License l;
    l.terms     = copyFontName(font, kCTFontLicenseNameKey);
    l.url       = copyFontName(font, kCTFontLicenseURLNameKey);
    l.copyright = copyFontName(font, kCTFontCopyrightNameKey);
    l.vendor    = copyFontName(font, kCTFontManufacturerNameKey);
    return l;
}

bool containsNoCase(const std::string &haystack, const std::string &needle) {
    if (needle.empty()) return true;
    auto it = std::search(haystack.begin(), haystack.end(), needle.begin(), needle.end(),
                          [](char a, char b) { return tolower(a) == tolower(b); });
    return it != haystack.end();
}

uint32_t axisIdentifier(CFDictionaryRef axis) {
    CFNumberRef n = (CFNumberRef)CFDictionaryGetValue(axis, kCTFontVariationAxisIdentifierKey);
    uint32_t id = 0;
    if (n) CFNumberGetValue(n, kCFNumberSInt32Type, &id);
    return id;
}

double axisNumber(CFDictionaryRef axis, CFStringRef key) {
    CFNumberRef n = (CFNumberRef)CFDictionaryGetValue(axis, key);
    double v = 0;
    if (n) CFNumberGetValue(n, kCFNumberDoubleType, &v);
    return v;
}

// A descriptor to render plus the axis and value that produced it.
struct Instance {
    CTFontDescriptorRef desc;
    std::string axis;
    double value;
};

// Instances of a variable font along one axis, preferring weight. These are
// real typefaces the designer specified, not affine copies of one bitmap, so
// they are honest extra samples rather than augmentation noise.
std::vector<Instance> variationInstances(CTFontDescriptorRef desc, CGFloat renderSize, int count) {
    std::vector<Instance> out;

    CTFontRef probe = CTFontCreateWithFontDescriptor(desc, renderSize, nullptr);
    if (!probe) return out;
    CFArrayRef axes = CTFontCopyVariationAxes(probe);
    CFRelease(probe);
    if (!axes) return out;

    CFDictionaryRef chosen = nullptr;
    for (CFIndex i = 0, n = CFArrayGetCount(axes); i < n; i++) {
        CFDictionaryRef a = (CFDictionaryRef)CFArrayGetValueAtIndex(axes, i);
        if (axisIdentifier(a) == kWeightAxisTag) { chosen = a; break; }
        if (!chosen) chosen = a;
    }
    if (!chosen) { CFRelease(axes); return out; }

    const uint32_t tag = axisIdentifier(chosen);
    const double lo = axisNumber(chosen, kCTFontVariationAxisMinimumValueKey);
    const double hi = axisNumber(chosen, kCTFontVariationAxisMaximumValueKey);
    if (!(hi > lo)) { CFRelease(axes); return out; }

    for (int i = 0; i < count; i++) {
        double v = (count == 1) ? (lo + hi) / 2.0
                                : lo + (hi - lo) * (double)i / (double)(count - 1);

        CFNumberRef key = CFNumberCreate(nullptr, kCFNumberSInt32Type, &tag);
        CFNumberRef val = CFNumberCreate(nullptr, kCFNumberDoubleType, &v);
        CFDictionaryRef variation = CFDictionaryCreate(nullptr,
            (const void **)&key, (const void **)&val, 1,
            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFStringRef attrKey = kCTFontVariationAttribute;
        CFDictionaryRef attrs = CFDictionaryCreate(nullptr,
            (const void **)&attrKey, (const void **)&variation, 1,
            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

        CTFontDescriptorRef instance = CTFontDescriptorCreateCopyWithAttributes(desc, attrs);
        CFRelease(attrs); CFRelease(variation); CFRelease(key); CFRelease(val);

        if (instance) out.push_back({instance, TextUtil::fourCharCode(tag), v});
    }
    CFRelease(axes);
    return out;
}

// Keeps at most n faces per family, spread across the family's weight range
// rather than taken in file order, so a cap of 3 gives something like
// light/regular/bold instead of three adjacent cuts.
void capPerFamily(std::vector<Job> &jobs, long n, Tally *tally) {
    if (n <= 0) return;

    std::map<std::string, std::vector<size_t>> byFamily;
    for (size_t i = 0; i < jobs.size(); i++) byFamily[jobs[i].family].push_back(i);

    std::vector<bool> keep(jobs.size(), false);
    for (auto &entry : byFamily) {
        std::vector<size_t> &idx = entry.second;
        if ((long)idx.size() <= n) {
            for (size_t i : idx) keep[i] = true;
            continue;
        }
        std::sort(idx.begin(), idx.end(), [&](size_t a, size_t b) {
            if (jobs[a].traits.weight != jobs[b].traits.weight)
                return jobs[a].traits.weight < jobs[b].traits.weight;
            return jobs[a].name < jobs[b].name;
        });
        for (long i = 0; i < n; i++) {
            size_t pick = (n == 1) ? idx.size() / 2
                                   : (size_t)llround((double)i * (idx.size() - 1) / (n - 1));
            keep[idx[pick]] = true;
        }
    }

    std::vector<Job> kept;
    for (size_t i = 0; i < jobs.size(); i++) {
        if (keep[i]) kept.push_back(jobs[i]);
        else { CFRelease(jobs[i].desc); tally->familyCapped++; }
    }
    jobs.swap(kept);
}

}  // namespace

std::vector<CTFontDescriptorRef> descriptorsInDirectories(const std::vector<std::string> &dirs) {
    std::vector<CTFontDescriptorRef> out;
    NSFileManager *fm = [NSFileManager defaultManager];

    for (const std::string &dir : dirs) {
        NSString *path = [NSString stringWithUTF8String:TextUtil::expandTilde(dir).c_str()];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:path isDirectory:&isDir]) {
            fprintf(stderr, "  note: %s does not exist, skipping\n", dir.c_str());
            continue;
        }

        NSMutableArray<NSURL *> *files = [NSMutableArray array];
        if (isDir) {
            NSDirectoryEnumerator<NSURL *> *e =
                [fm enumeratorAtURL:[NSURL fileURLWithPath:path]
                 includingPropertiesForKeys:@[NSURLIsRegularFileKey]
                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                               errorHandler:nil];
            for (NSURL *url in e) {
                if (isFontFile(url.path)) [files addObject:url];
            }
        } else if (isFontFile(path)) {
            [files addObject:[NSURL fileURLWithPath:path]];
        }

        // One file can hold many faces: .ttc/.otc collections, which is how
        // Apple ships most of the system fonts. Hence descriptors-from-URL
        // rather than one font per file.
        for (NSURL *url in files) {
            CFArrayRef descs = CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url);
            if (!descs) continue;
            for (CFIndex i = 0, n = CFArrayGetCount(descs); i < n; i++) {
                CTFontDescriptorRef d = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descs, i);
                CFRetain(d);
                out.push_back(d);
            }
            CFRelease(descs);
        }
    }
    return out;
}

std::vector<Job> buildJobs(const std::vector<CTFontDescriptorRef> &descriptors,
                           const std::vector<UniChar> &chars,
                           const Options &opt,
                           CGFloat renderSize,
                           Tally *tally) {
    std::vector<Job> jobs;
    std::unordered_set<std::string> seen;

    for (CTFontDescriptorRef base : descriptors) {
        std::string name = copyStringAttribute(base, kCTFontNameAttribute);
        if (name.empty()) { tally->unreadable++; continue; }
        // A leading dot marks one of Apple's private UI faces (.SFNS,
        // .PingFang). They're near-duplicate optical grades rather than
        // distinct typefaces, and the dot would write a hidden file.
        if (name[0] == '.' && !opt.includePrivate) { tally->privateFaces++; continue; }
        if (!seen.insert(name).second) { tally->duplicates++; continue; }

        std::string family = copyStringAttribute(base, kCTFontFamilyNameAttribute);
        if (family.empty()) family = name;
        Traits traits = readTraits(base);

        std::vector<Instance> instances;
        if (opt.variations > 1) instances = variationInstances(base, renderSize, opt.variations);
        if (instances.empty()) {
            CFRetain(base);
            instances.push_back({base, "", 0.0});
        }

        for (const Instance &inst : instances) {
            CTFontRef font = CTFontCreateWithFontDescriptor(inst.desc, renderSize, nullptr);
            if (!font) { CFRelease(inst.desc); tally->unreadable++; continue; }

            License license = readLicense(font);
            if (!opt.licenseFilter.empty() &&
                !containsNoCase(license.terms, opt.licenseFilter) &&
                !containsNoCase(license.url, opt.licenseFilter)) {
                CFRelease(font);
                CFRelease(inst.desc);
                tally->licenseFiltered++;
                continue;
            }

            std::vector<CGGlyph> glyphs(chars.size());
            // False if any character is unmapped. Skip those rather than write
            // a .notdef box. Drawing by glyph id also means Core Text won't
            // quietly substitute another family and mislabel the sample.
            bool complete = CTFontGetGlyphsForCharacters(font, chars.data(), glyphs.data(),
                                                         (CFIndex)chars.size());
            CFRelease(font);
            if (!complete) { CFRelease(inst.desc); tally->noGlyph++; continue; }

            Job job;
            job.desc = inst.desc;
            job.name = name;
            job.family = family;
            job.axis = inst.axis;
            job.axisValue = inst.value;
            job.traits = traits;
            job.license = std::move(license);
            job.glyphs = std::move(glyphs);
            if (!job.axis.empty()) {
                job.name += "_" + job.axis + std::to_string((long)llround(job.axisValue));
            }
            jobs.push_back(std::move(job));
        }
    }

    capPerFamily(jobs, opt.perFamily, tally);

    if (opt.limit > 0 && (long)jobs.size() > opt.limit) {
        for (size_t i = opt.limit; i < jobs.size(); i++) CFRelease(jobs[i].desc);
        jobs.resize(opt.limit);
    }
    return jobs;
}

void releaseJobs(std::vector<Job> &jobs) {
    for (Job &j : jobs) if (j.desc) CFRelease(j.desc);
    jobs.clear();
}

}  // namespace FontCatalog
