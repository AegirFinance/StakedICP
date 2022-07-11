SOURCE ?= ../src
MOC ?= $(shell vessel bin)/moc
WASMTIME_OPTIONS = --disable-cache

OUTDIR=_out

TESTS = $(wildcard **/*.mo)

TEST_TARGETS = $(patsubst %.mo,_out/%.checked,$(TESTS))

all: $(TEST_TARGETS)

# TODO: For now, moc doesn't support compiling async expressions for wasmtime,
# so we can't import those. boooh.
# all: $(OUTDIR)/import_all.checked $(TEST_TARGETS)

SOURCE_FILES= $(wildcard $(SOURCE)/**/*.mo)

LOCAL_PKGS= \
			--package deposits $(SOURCE)/deposits \
			--package governance $(SOURCE)/governance \
			--package ledger $(SOURCE)/ledger \
			--package metrics $(SOURCE)/metrics

VESSEL_PKGS= $(shell vessel sources)

$(OUTDIR):
	@mkdir $@

$(OUTDIR)/import_all.mo: $(SOURCE_FILES) | $(OUTDIR)
	> $@
	for f in $(patsubst $(SOURCE)/%.mo,%,$(SOURCE_FILES)); do \
		echo "import Import_$$(echo $$f | tr '/' '_') \"mo:$$f\";" >> $@; \
	done

$(OUTDIR)/%.wasm: %.mo | $(OUTDIR)
	@mkdir -p $(@D)
	$(MOC) -c $(LOCAL_PKGS) $(VESSEL_PKGS) -wasi-system-api -o $@ $< --debug

$(OUTDIR)/%.wasm: $(OUTDIR)/%.mo | $(OUTDIR)
	@mkdir -p $(@D)
	$(MOC) -c $(LOCAL_PKGS) $(VESSEL_PKGS) -wasi-system-api -o $@ $< --debug

$(OUTDIR)/%.checked: $(OUTDIR)/%.wasm
	@mkdir -p $(@D)
	wasmtime run $(WASMTIME_OPTIONS) $<
	touch $@

clean:
	rm -rf $(OUTDIR)

.PRECIOUS: $(OUTDIR)/%.wasm
