# Four system frameworks, no external dependencies.
BIN      := fontscrape
BUILD    := build
DIST     := dist
PREFIX   ?= /usr/local

SRCS     := $(wildcard src/*.mm)
OBJS     := $(patsubst src/%.mm,$(BUILD)/%.o,$(SRCS))
DEPS     := $(OBJS:.o=.d)

CXXFLAGS := -std=c++17 -O2 -Wall -Wextra -fobjc-arc
LDFLAGS  := -framework CoreText -framework CoreGraphics \
            -framework ImageIO -framework Foundation

# Release binaries carry both architectures and target the oldest macOS that
# has the Core Text APIs used here, so one download runs anywhere. A local
# build stays native, which keeps the edit-compile loop quick.
UNIVERSAL_ARCHS := -arch x86_64 -arch arm64
DEPLOYMENT_TARGET := 11.0

$(BIN): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

# Incremental builds need per-object dependency files; the release build is one
# shot across every source, so it doesn't.
$(BUILD)/%.o: src/%.mm | $(BUILD)
	$(CXX) $(CXXFLAGS) -MMD -MP -c -o $@ $<

$(BUILD) $(DIST):
	@mkdir -p $@

universal: | $(DIST)
	$(CXX) $(CXXFLAGS) $(UNIVERSAL_ARCHS) \
	    -mmacosx-version-min=$(DEPLOYMENT_TARGET) \
	    -o $(DIST)/$(BIN) $(SRCS) $(LDFLAGS)
	@lipo -archs $(DIST)/$(BIN)

install: $(BIN)
	install -d $(PREFIX)/bin
	install -m 755 $(BIN) $(PREFIX)/bin/$(BIN)

clean:
	rm -rf $(BUILD) $(DIST) $(BIN)

-include $(DEPS)

.PHONY: universal install clean
