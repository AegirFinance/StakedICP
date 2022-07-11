SOURCE ?= ../src
MOC ?= $(shell vessel bin)/moc
WASMTIME_OPTIONS = --disable-cache

OUTDIR=_out

TESTS = $(wildcard *.mo)

TEST_TARGETS = $(patsubst %.mo,_out/%.checked,$(TESTS))

all: $(OUTDIR)/import_all.checked $(TEST_TARGETS)

SOURCE_FILES= $(wildcard $(SOURCE)/*.mo)

VESSEL_PKGS= $(shell vessel sources)

$(OUTDIR):
	@mkdir $@

$(OUTDIR)/import_all.mo: $(SOURCE_FILES) | $(OUTDIR)
	> $@
	for f in $(patsubst $(SOURCE)/%.mo,%,$(SOURCE_FILES)); do \
	  echo "import Import_$$f \"mo:base/$$f\";" >> $@; \
	done

$(OUTDIR)/%.wasm: %.mo | $(OUTDIR)
	$(MOC) -c --package base $(SOURCE) $(VESSEL_PKGS) -wasi-system-api -o $@ $<

$(OUTDIR)/%.wasm: $(OUTDIR)/%.mo | $(OUTDIR)
	$(MOC) -c --package base $(SOURCE) $(VESSEL_PKGS) -wasi-system-api -o $@ $<

$(OUTDIR)/%.checked: $(OUTDIR)/%.wasm
	wasmtime run $(WASMTIME_OPTIONS) $<
	touch $@

clean:
	rm -rf $(OUTDIR)

.PRECIOUS: $(OUTDIR)/%.wasm
