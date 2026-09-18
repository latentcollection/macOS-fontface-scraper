#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

#include "GlyphRenderer.h"

#include <algorithm>

namespace GlyphRenderer {
namespace {

// Glyphs are monochrome letterforms, so one 8-bit channel holds everything an
// RGB buffer would at a third of the bytes.
const size_t kBitsPerComponent = 8;
const size_t kBytesPerPixel = 1;

const CGFloat kOpaque = 1.0;
const CGFloat kBlack = 0.0;
const CGFloat kWhite = 1.0;

// Where the run sits before any centring is applied.
const CGFloat kBaselineOrigin = 0.0;

struct RunLayout {
    std::vector<CGPoint> positions;
    CGRect ink;
    CGFloat advance;
};

// Lays the run out on a baseline at the origin and unions the ink boxes.
bool layoutRun(CTFontRef font, const std::vector<CGGlyph> &glyphs, RunLayout *out) {
    const size_t n = glyphs.size();

    std::vector<CGSize> advances(n);
    CTFontGetAdvancesForGlyphs(font, kCTFontOrientationDefault, glyphs.data(),
                               advances.data(), (CFIndex)n);
    std::vector<CGRect> bounds(n);
    CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationDefault, glyphs.data(),
                                    bounds.data(), (CFIndex)n);

    out->positions.resize(n);
    out->advance = 0;
    out->ink = CGRectNull;
    for (size_t i = 0; i < n; i++) {
        out->positions[i] = CGPointMake(out->advance, kBaselineOrigin);
        if (!CGRectIsEmpty(bounds[i]) && !CGRectIsNull(bounds[i])) {
            out->ink = CGRectUnion(out->ink, CGRectOffset(bounds[i], out->advance, kBaselineOrigin));
        }
        out->advance += advances[i].width;
    }
    return !CGRectIsNull(out->ink) && out->ink.size.width > 0 && out->ink.size.height > 0;
}

CGContextRef makeCanvas(size_t px, bool invert) {
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(nullptr, px, px, kBitsPerComponent,
                                             px * kBytesPerPixel, gray, kCGImageAlphaNone);
    CGColorSpaceRelease(gray);
    if (!ctx) return nullptr;

    CGContextSetGrayFillColor(ctx, invert ? kWhite : kBlack, kOpaque);
    CGContextFillRect(ctx, CGRectMake(0, 0, px, px));
    CGContextSetGrayFillColor(ctx, invert ? kBlack : kWhite, kOpaque);

    CGContextSetShouldAntialias(ctx, true);
    CGContextSetAllowsAntialiasing(ctx, true);
    // Subpixel tricks assume an RGB target and smear a single-channel buffer.
    CGContextSetShouldSmoothFonts(ctx, false);
    CGContextSetShouldSubpixelPositionFonts(ctx, false);
    CGContextSetShouldSubpixelQuantizeFonts(ctx, false);
    return ctx;
}

CGFloat scaleToFit(CGRect ink, CGFloat available) {
    return std::min(available / ink.size.width, available / ink.size.height);
}

// Applies the transform that places the run on the canvas. The glyph is still
// an outline at this point, so scaling costs no resolution.
void applyPlacement(CGContextRef ctx, CTFontRef font, const Options &opt,
                    const RunLayout &layout, CGFloat px) {
    const CGFloat available = px * (1.0 - 2.0 * opt.margin);

    if (opt.mode == FitMode::Metric) {
        // Lay out against the reference canvas and scale to the real one, so
        // --point-size keeps its meaning across a size sweep.
        const CGFloat ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font);
        const CGFloat baseline =
            (Layout::kReferenceCanvas - (ascent + descent)) / 2.0 + descent;
        CGContextScaleCTM(ctx, px / Layout::kReferenceCanvas, px / Layout::kReferenceCanvas);
        CGContextTranslateCTM(ctx, (Layout::kReferenceCanvas - layout.advance) / 2.0, baseline);
        return;
    }

    CGFloat scale;
    if (opt.mode == FitMode::Fit) {
        scale = scaleToFit(layout.ink, available);
    } else {
        // Normalize on x-height rather than on the ink box, so a condensed light
        // and a black extended cut of the same design keep their different
        // widths and weights instead of being squashed to one size.
        CGFloat reference = CTFontGetXHeight(font);
        if (reference <= 0) {
            reference = CTFontGetCapHeight(font) * Layout::kXHeightPerCapHeight;
        }
        scale = reference > 0 ? (opt.xHeightTarget * px) / reference
                              : scaleToFit(layout.ink, available);
        // Display and script faces have x-heights that bear no relation to their
        // ink, so clamp anything that would overflow the canvas.
        scale = std::min(scale, scaleToFit(layout.ink, available));
    }

    CGContextTranslateCTM(ctx, px / 2.0, px / 2.0);
    CGContextScaleCTM(ctx, scale, scale);
    CGContextTranslateCTM(ctx, -CGRectGetMidX(layout.ink), -CGRectGetMidY(layout.ink));
}

bool writePNG(CGContextRef ctx, const std::string &path) {
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    if (!image) return false;

    NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path.c_str()]];
    // "public.png" over kUTTypePNG: the constant moved frameworks and is
    // deprecated, the identifier string isn't.
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL(
        (__bridge CFURLRef)url, CFSTR("public.png"), 1, nullptr);
    if (!dest) { CGImageRelease(image); return false; }

    CGImageDestinationAddImage(dest, image, nullptr);
    bool ok = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    CGImageRelease(image);
    return ok;
}

}  // namespace

bool renderToPNG(CTFontRef font,
                 const std::vector<CGGlyph> &glyphs,
                 const Options &opt,
                 int canvas,
                 const std::string &outPath) {
    RunLayout layout;
    if (!layoutRun(font, glyphs, &layout)) return false;

    const size_t px = static_cast<size_t>(canvas);
    CGContextRef ctx = makeCanvas(px, opt.invert);
    if (!ctx) return false;

    applyPlacement(ctx, font, opt, layout, (CGFloat)px);
    CTFontDrawGlyphs(font, glyphs.data(), layout.positions.data(), glyphs.size(), ctx);

    bool ok = writePNG(ctx, outPath);
    CGContextRelease(ctx);
    return ok;
}

}  // namespace GlyphRenderer
