# oocpio v0.2.0 Makefile

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/oocpio

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= $(shell cat VERSION 2>/dev/null || echo 0.2.0)

.PHONY: build check line-cap file-law academy density verify clean test package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@cp -a $(BIN) dist/oocpio-linux-x86_64
	@sha256sum dist/oocpio-linux-x86_64 > dist/oocpio-linux-x86_64.sha256
	@echo "built $(BIN) (and dist/oocpio-linux-x86_64)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot" | grep -v "/dist/" | grep -v "/.ooda-cache/"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.sh" -not -path "./.git/*" -not -path "./dist/*" 2>/dev/null); do \
		if [ "$$f" != "./install.sh" ] && [ "$$f" != "./uninstall.sh" ]; then \
			echo "VIOLATION: .sh forbidden outside install.sh and uninstall.sh: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*" -not -path "./qa*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== testing --help ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@echo "=== testing --version ==="
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@echo "=== testing --demo ==="
	@./$(BIN) --demo | grep -q "init" && echo "PASS: --demo"
	@echo "=== testing --demo --json ==="
	@./$(BIN) --demo --json | grep -q '"tool":"oocpio"' && echo "PASS: --demo --json"
	@echo "=== testing archive creation and listing ==="
	@printf "sovereign kernel payload\n" > dist/file_test.txt
	@./$(BIN) -o -F dist/test.cpio dist/file_test.txt
	@test -f dist/test.cpio && echo "PASS: archive created"
	@./$(BIN) -t -F dist/test.cpio | grep -q "dist/file_test.txt" && echo "PASS: archive list"
	@echo "=== testing archive extraction ==="
	@mkdir -p dist/extracted
	@./$(BIN) -i -F dist/test.cpio -C dist/extracted
	@grep -q "sovereign kernel payload" dist/extracted/dist/file_test.txt && echo "PASS: archive extracted"
	@echo "=== testing MCP initialize ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "protocolVersion" && echo "PASS: MCP initialize"
	@echo "=== testing MCP tools/list ==="
	@printf '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "cpio_list_archive" && echo "PASS: MCP tools/list"
	@echo "=== testing MCP tools/call cpio_list_archive ==="
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","name":"cpio_list_archive"}\n' | ./$(BIN) --mcp | grep -q 'init' && echo "PASS: MCP cpio_list_archive"
	@echo "=== testing MCP tools/call cpio_inspect_header ==="
	@printf '{"jsonrpc":"2.0","id":4,"method":"tools/call","name":"cpio_inspect_header"}\n' | ./$(BIN) --mcp | grep -q 'newc' && echo "PASS: MCP cpio_inspect_header"
	@echo "=== testing MCP tools/call cpio_demo ==="
	@printf '{"jsonrpc":"2.0","id":5,"method":"tools/call","name":"cpio_demo"}\n' | ./$(BIN) --mcp | grep -q 'total_entries' && echo "PASS: MCP cpio_demo"
	@echo "=== testing MCP tools/call cpio_stats ==="
	@printf '{"jsonrpc":"2.0","id":6,"method":"tools/call","name":"cpio_stats"}\n' | ./$(BIN) --mcp | grep -q 'total_files' && echo "PASS: MCP cpio_stats"
	@rm -rf dist/file_test.txt dist/test.cpio dist/extracted
	@echo "ALL TESTS PASSED"

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/oocpio
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/oocpio-uninstall
	@echo "installed oocpio and oocpio-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/oocpio $(DESTDIR)$(BINDIR)/oocpio-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/oocpio $(HOME)/.config/oocpio; echo "purged user cache and config"; fi
	@echo "uninstalled oocpio and oocpio-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/oocpio
	@chmod 0755 dist/deb-root/usr/bin/oocpio
	@cp uninstall.sh dist/deb-root/usr/bin/oocpio-uninstall
	@chmod 0755 dist/deb-root/usr/bin/oocpio-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/oocpio_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/oocpio_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/oocpio-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/oocpio.spec > ~/rpmbuild/SPECS/oocpio.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/oocpio.spec
	@cp ~/rpmbuild/RPMS/x86_64/oocpio-$(VERSION)*.rpm dist/
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/oocpio
	@chmod 0755 dist/arch-pkg/usr/bin/oocpio
	@cp uninstall.sh dist/arch-pkg/usr/bin/oocpio-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/oocpio-uninstall
	@printf "pkgname = oocpio\npkgbase = oocpio\npkgver = $(VERSION)-1\npkgdesc = Initramfs cpio format unpacker and archiver for Linux kernel boot images.\nurl = https://github.com/openOODA-tools/oocpio\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = oocpio\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/oocpio-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/oocpio-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cd dist && sha256sum oocpio* > checksums.txt 2>/dev/null || true
	@echo "built all packages and dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"
