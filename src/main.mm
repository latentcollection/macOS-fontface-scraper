// Rasterizes glyphs from the fonts installed on this Mac to grayscale PNGs.

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#include "FontCatalog.h"
#include "GlyphRenderer.h"
#include "Manifest.h"
#include "Options.h"
#include "TextUtil.h"

#include <atomic>
#include <string>
#include <unistd.h>
#include <vector>

namespace {

const char *kStandardFontDirs[] = {
    "~/Library/Fonts",
    "/Library/Fonts",
    "/System/Library/Fonts",
    "/Network/Library/Fonts",
};

const char *kManifestFilename = "manifest.csv";

void printUsage(const char *argv0) {
    fprintf(stderr,
        "usage: %s [options] [font-dir ...]\n"
        "\n"
        "Rasterizes glyphs from every installed font to grayscale PNGs.\n"
        "With no font-dir given, prompts and defaults to the standard macOS\n"
        "font directories.\n"
        "\n"
        "  --glyph <str>     one glyph, written flat into --out (default: %s)\n"
        "  --glyphs <list>   several glyphs, one subdirectory each\n"
        "  --size <px>       one size, written flat into --out  (default: %d)\n"
        "  --sizes <list>    several sizes, one subdirectory each\n"
        "  --mode <m>        fit | xheight | metric             (default: fit)\n"
        "  --point-size <pt> font size, metric mode only        (default: %g)\n"
        "  --margin <frac>   edge padding                       (default: %.2f)\n"
        "  --xheight <frac>  x-height as a fraction of the canvas, xheight\n"
        "                    mode only                          (default: %.2f)\n"
        "  --out <dir>       output directory                   (default: out)\n"
        "  --per-family <n>  keep at most n faces per family, spread by weight\n"
        "  --variations <n>  sample n instances of each variable font\n"
        "  --manifest        also write manifest.csv of font metadata\n"
        "  --license <text>  keep only faces whose embedded license or its URL\n"
        "                    contains this text, e.g. --license OFL\n"
        "  --limit <n>       cap images per glyph, 0 = all      (default: 0)\n"
        "  --invert          black ink on white\n"
        "  --list            list matching fonts, render nothing\n"
        "  --include-private include Apple's hidden system faces (.SFNS etc)\n"
        "  -y, --yes         use defaults, never prompt\n"
        "  -h, --help\n"
        "\n"
        "--glyphs takes either one character per glyph (--glyphs abc) or a\n"
        "comma-separated list when entries are longer than a character\n"
        "(--glyphs a,Ag,%%). --sizes is always comma-separated.\n"
        "\n"
        "The plural flags always create a subdirectory per value, so\n"
        "--glyphs a gives out/a/ where --glyph a gives out/. Sizes nest\n"
        "outside glyphs: --sizes 128,256 --glyphs a,b gives out/128/a/ and so\n"
        "on, which is the layout torchvision's ImageFolder expects.\n",
        argv0, Layout::kDefaultGlyph, Limits::kDefaultCanvas, Layout::kDefaultPointSize,
        Layout::kDefaultMargin, Layout::kDefaultXHeightTarget);
}

std::vector<std::string> standardFontDirs() {
    return std::vector<std::string>(std::begin(kStandardFontDirs), std::end(kStandardFontDirs));
}

std::vector<std::string> promptForFontDirs() {
    std::vector<std::string> defaults = standardFontDirs();
    if (!isatty(STDIN_FILENO)) return defaults;

    fprintf(stderr, "Where are your fonts? Default:\n");
    for (const std::string &d : defaults) fprintf(stderr, "  %s\n", d.c_str());
    fprintf(stderr, "Path (return to accept): ");
    fflush(stderr);

    char buf[Limits::kMaxPathInput];
    if (!fgets(buf, sizeof buf, stdin)) return defaults;

    std::string line(buf);
    line.erase(line.find_last_not_of(" \t\r\n") + 1);
    line.erase(0, line.find_first_not_of(" \t"));
    return line.empty() ? defaults : std::vector<std::string>{line};
}

bool makeDirectory(const std::string &path, std::string *errOut) {
    NSError *err = nil;
    NSString *dir = [NSString stringWithUTF8String:path.c_str()];
    if ([[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&err]) {
        return true;
    }
    if (errOut) *errOut = err.localizedDescription.UTF8String;
    return false;
}

// Returns false and prints the reason when a flag is out of range.
bool validate(const Options &opt) {
    if (opt.sizes.empty()) {
        fprintf(stderr, "error: --sizes needs at least one size\n");
        return false;
    }
    for (int s : opt.sizes) {
        if (s < Limits::kMinCanvas || s > Limits::kMaxCanvas) {
            fprintf(stderr, "error: size %d out of range, must be %d to %d\n",
                    s, Limits::kMinCanvas, Limits::kMaxCanvas);
            return false;
        }
    }
    if (opt.margin < 0.0 || opt.margin >= Limits::kMaxMargin) {
        fprintf(stderr, "error: --margin must be in [0, %.1f)\n", Limits::kMaxMargin);
        return false;
    }
    if (opt.xHeightTarget <= 0.0 || opt.xHeightTarget > 1.0) {
        fprintf(stderr, "error: --xheight must be in (0, 1]\n");
        return false;
    }
    if (opt.variations < Limits::kMinVariations || opt.variations > Limits::kMaxVariations) {
        fprintf(stderr, "error: --variations must be between %d and %d\n",
                Limits::kMinVariations, Limits::kMaxVariations);
        return false;
    }
    if (opt.glyphs.empty()) {
        fprintf(stderr, "error: no glyphs given\n");
        return false;
    }
    for (const std::string &g : opt.glyphs) {
        if (g.empty()) { fprintf(stderr, "error: empty glyph in list\n"); return false; }
    }
    return true;
}

// Returns false when the arguments are malformed; *exitNow is set for --help.
bool parseArguments(int argc, const char *argv[], Options *opt, bool *exitNow) {
    *exitNow = false;

    for (int i = 1; i < argc; i++) {
        std::string a = argv[i];
        auto next = [&](const char *what) -> std::string {
            if (i + 1 >= argc) {
                fprintf(stderr, "error: %s requires a value\n", what);
                exit(2);
            }
            return argv[++i];
        };

        if (a == "--glyph") {
            opt->glyphs = {next("--glyph")};
            opt->glyphSubdirs = false;
        } else if (a == "--glyphs") {
            opt->glyphs = TextUtil::parseGlyphList(next("--glyphs"));
            opt->glyphSubdirs = true;
        } else if (a == "--size") {
            opt->sizes = {std::stoi(next("--size"))};
            opt->sizeSubdirs = false;
        } else if (a == "--sizes") {
            opt->sizes.clear();
            for (const std::string &s : TextUtil::splitOnCommas(next("--sizes"))) {
                opt->sizes.push_back(std::stoi(s));
            }
            opt->sizeSubdirs = true;
        } else if (a == "--mode") {
            std::string m = next("--mode");
            if      (m == "fit")     opt->mode = FitMode::Fit;
            else if (m == "metric")  opt->mode = FitMode::Metric;
            else if (m == "xheight") opt->mode = FitMode::XHeight;
            else {
                fprintf(stderr, "error: --mode must be 'fit', 'xheight' or 'metric'\n");
                return false;
            }
        }
        else if (a == "--point-size")      opt->pointSize     = std::stod(next("--point-size"));
        else if (a == "--margin")          opt->margin        = std::stod(next("--margin"));
        else if (a == "--xheight")         opt->xHeightTarget = std::stod(next("--xheight"));
        else if (a == "--out")             opt->outDir        = next("--out");
        else if (a == "--limit")           opt->limit         = std::stol(next("--limit"));
        else if (a == "--per-family")      opt->perFamily     = std::stol(next("--per-family"));
        else if (a == "--variations")      opt->variations    = std::stoi(next("--variations"));
        else if (a == "--manifest")        opt->manifest      = true;
        else if (a == "--license")         opt->licenseFilter = next("--license");
        else if (a == "--invert")          opt->invert        = true;
        else if (a == "--list")            opt->listOnly      = true;
        else if (a == "--include-private") opt->includePrivate = true;
        else if (a == "-y" || a == "--yes") opt->assumeYes    = true;
        else if (a == "--help" || a == "-h") { printUsage(argv[0]); *exitNow = true; return true; }
        else if (!a.empty() && a[0] == '-') {
            fprintf(stderr, "error: unknown option '%s'\n\n", a.c_str());
            printUsage(argv[0]);
            return false;
        }
        else opt->fontDirs.push_back(a);
    }
    return true;
}

// Renders every job at one canvas size into one directory, in parallel.
// Each iteration owns its context and its output file, so the counters are the
// only shared state. Captured by pointer because blocks can't copy an atomic.
long renderAll(const std::vector<FontCatalog::Job> &jobs,
               const Options &opt,
               int canvas,
               const std::string &dir,
               std::vector<uint8_t> *succeeded,
               long *blankOut) {
    std::atomic<long> written{0}, blank{0};
    std::atomic<long> *pWritten = &written, *pBlank = &blank;
    succeeded->assign(jobs.size(), 0);
    uint8_t *pOk = succeeded->data();
    const FontCatalog::Job *pJobs = jobs.data();
    const Options *pOpt = &opt;
    const std::string *pDir = &dir;
    const CGFloat renderSize =
        (opt.mode == FitMode::Metric) ? opt.pointSize : Layout::kReferenceCanvas;

    dispatch_apply(jobs.size(), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
                   ^(size_t i) {
        @autoreleasepool {
            const FontCatalog::Job &job = pJobs[i];
            CTFontRef font = CTFontCreateWithFontDescriptor(job.desc, renderSize, nullptr);
            if (!font) return;

            std::string path = *pDir + "/" + TextUtil::sanitizeFilename(job.name) + ".png";
            if (GlyphRenderer::renderToPNG(font, job.glyphs, *pOpt, canvas, path)) {
                pOk[i] = 1;
                (*pWritten)++;
            } else {
                (*pBlank)++;
            }
            CFRelease(font);
        }
    });

    *blankOut = blank.load();
    return written.load();
}

}  // namespace

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        Options opt;
        bool exitNow = false;
        if (!parseArguments(argc, argv, &opt, &exitNow)) return 2;
        if (exitNow) return 0;
        if (!validate(opt)) return 2;

        if (opt.fontDirs.empty()) {
            opt.fontDirs = opt.assumeYes ? standardFontDirs() : promptForFontDirs();
        }

        std::vector<CTFontDescriptorRef> descriptors =
            FontCatalog::descriptorsInDirectories(opt.fontDirs);
        if (descriptors.empty()) {
            fprintf(stderr, "error: no font files found\n");
            return 1;
        }

        const CGFloat renderSize =
            (opt.mode == FitMode::Metric) ? opt.pointSize : Layout::kReferenceCanvas;
        const bool sweeping = opt.glyphs.size() > 1 || opt.sizes.size() > 1;
        long grandTotal = 0;
        Manifest manifest;

        for (const std::string &glyph : opt.glyphs) {
            std::vector<UniChar> chars = TextUtil::toUTF16(glyph);
            if (chars.empty()) {
                fprintf(stderr, "error: could not decode '%s' as UTF-8\n", glyph.c_str());
                return 2;
            }

            FontCatalog::Tally tally;
            std::vector<FontCatalog::Job> jobs =
                FontCatalog::buildJobs(descriptors, chars, opt, renderSize, &tally);

            if (opt.listOnly) {
                for (const FontCatalog::Job &j : jobs) printf("%s\n", j.name.c_str());
                fprintf(stderr, "%zu fonts contain \"%s\"\n", jobs.size(), glyph.c_str());
                grandTotal += jobs.size();
                FontCatalog::releaseJobs(jobs);
                continue;
            }

            for (int canvas : opt.sizes) {
                std::string relative;
                if (opt.sizeSubdirs)  relative += std::to_string(canvas) + "/";
                if (opt.glyphSubdirs) relative += TextUtil::sanitizeFilename(glyph) + "/";
                std::string dir = relative.empty() ? opt.outDir : opt.outDir + "/" + relative;

                std::string err;
                if (!makeDirectory(dir, &err)) {
                    fprintf(stderr, "error: could not create '%s': %s\n", dir.c_str(), err.c_str());
                    FontCatalog::releaseJobs(jobs);
                    return 1;
                }

                std::vector<uint8_t> succeeded;
                long blank = 0;
                long written = renderAll(jobs, opt, canvas, dir, &succeeded, &blank);

                if (opt.manifest) {
                    for (size_t i = 0; i < jobs.size(); i++) {
                        if (!succeeded[i]) continue;
                        manifest.add(jobs[i],
                                     relative + TextUtil::sanitizeFilename(jobs[i].name) + ".png",
                                     glyph, canvas);
                    }
                }

                grandTotal += written;
                if (sweeping) {
                    fprintf(stderr, "%s  %ld images at %dx%d\n",
                            dir.c_str(), written, canvas, canvas);
                } else {
                    fprintf(stderr,
                            "wrote %ld images (%dx%d grayscale PNG) to %s/\n"
                            "  skipped: %ld no glyph, %ld blank, %ld duplicate faces, "
                            "%ld private, %ld family-capped, %ld license-filtered, "
                            "%ld unreadable\n",
                            written, canvas, canvas, dir.c_str(),
                            tally.noGlyph, blank, tally.duplicates,
                            tally.privateFaces, tally.familyCapped,
                            tally.licenseFiltered, tally.unreadable);
                }
            }

            FontCatalog::releaseJobs(jobs);
        }

        for (CTFontDescriptorRef d : descriptors) CFRelease(d);

        if (opt.manifest && !opt.listOnly) {
            std::string path = opt.outDir + "/" + kManifestFilename;
            if (!manifest.writeTo(path)) {
                fprintf(stderr, "error: could not write %s\n", path.c_str());
                return 1;
            }
            fprintf(stderr, "manifest: %s\n", path.c_str());
        }

        if (sweeping && !opt.listOnly) {
            fprintf(stderr, "total %ld images across %zu glyph(s) and %zu size(s)\n",
                    grandTotal, opt.glyphs.size(), opt.sizes.size());
        }
        return grandTotal > 0 ? 0 : 1;
    }
}
