SHELL := /bin/bash
# .SHELLFLAGS := -e -o pipefail -c

GO_URL=https://go.dev/dl/
GO_INSTALL_DIR=/usr/local
GO_CURRENT_VERSION=$(shell if command -v go >/dev/null 2>&1; then go version | awk '{print $$3}' | sed 's/go//'; else echo "none"; fi)
LATEST_GO_VERSION=$(shell curl -s https://go.dev/VERSION?m=text | sed -nE 's/^go([0-9\.]+).*/\1/p')
GO_TARBALL=go$(LATEST_GO_VERSION).linux-amd64.tar.gz

GOPATH=$(HOME)/go
ESCAPED_GOPATH=$(shell echo $(GOPATH) | sed 's/\//\\\//g')
GOVULNCHECK_BINARY=govulncheck
GOLANGCI_LINT_BINARY=golangci-lint
VULNCHECK_PACKAGE=golang.org/x/vuln/cmd/$(GOVULNCHECK_BINARY)
LINT_PACKAGE=github.com/golangci/golangci-lint/cmd/$(GOLANGCI_LINT_BINARY)

# Module name for `go mod init` and the executable
MODULE_NAME=$(shell basename $(PWD))
LOCAL_BIN=$(HOME)/.local/bin/
TEMPLATE_REPO_URL := https://github.com/sss7526/go_maker.git

# ANSI
RED = \033[31m
GREEN = \033[32m
YELLOW = \033[33m
BLUE = \033[34m
RESET = \033[0m

COLOR_MSG = echo -e "$($(1))$(2)$(RESET)"

SUCCESS = $(call COLOR_MSG,GREEN,SUCCESS: $(1))
ERROR = $(call COLOR_MSG,RED,ERROR: $(1))
INFO = $(call COLOR_MSG,BLUE,INFO: $(1))
WARNING = $(call COLOR_MSG,YELLOW,WARNING: $(1))

# For fix_certs
DOMAINS = proxy.golang.org vuln.go.dev go.dev github.com www.github.com
CERT_DIR = /usr/local/share/ca-certificates


.PHONY: all install update uninstall help .validate_latest \
		govulncheck-install golangci-lint-install tool-install \
		lint vulncheck mod-init mod-tidy mod-update \
		run build build-dev tree ex clean fix_certs doctor

all: help

## Default target - show help
help:
	@COLUMNS=$$(tput cols); \
	BORDER=$$(printf '=%.0s' $$(seq 1 $$COLUMNS)); \
	HEADER1=" ██████╗  ██████╗       ███╗   ███╗ █████╗ ██╗  ██╗███████╗██████╗"; \
	HEADER2="██╔════╝ ██╔═══██╗      ████╗ ████║██╔══██╗██║ ██╔╝██╔════╝██╔══██╗"; \
	HEADER3="██║  ███╗██║   ██║█████╗██╔████╔██║███████║█████╔╝ █████╗  ██████╔╝"; \
	HEADER4="██║   ██║██║   ██║╚════╝██║╚██╔╝██║██╔══██║██╔═██╗ ██╔══╝  ██╔══██╗"; \
	HEADER5="╚██████╔╝╚██████╔╝      ██║ ╚═╝ ██║██║  ██║██║  ██╗███████╗██║  ██║"; \
	HEADER6=" ╚═════╝  ╚═════╝       ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"; \
	echo ""; \
	echo "$$BORDER"; \
	echo ""; \
	SPACES=$$((($$COLUMNS-$${#HEADER1})/2)); printf "%*s%s\n" $$SPACES "" "$$HEADER1"; \
	SPACES=$$((($$COLUMNS-$${#HEADER2})/2)); printf "%*s%s\n" $$SPACES "" "$$HEADER2"; \
	SPACES=$$((($$COLUMNS-$${#HEADER3})/2)); printf "%*s%s\n" $$SPACES "" "$$HEADER3"; \
	SPACES=$$((($$COLUMNS-$${#HEADER4})/2)); printf "%*s%s\n" $$SPACES "" "$$HEADER4"; \
	SPACES=$$((($$COLUMNS-$${#HEADER5})/2)); printf "%*s%s\n" $$SPACES "" "$$HEADER5"; \
	SPACES=$$((($$COLUMNS-$${#HEADER6})/2)); printf "%*s%s\n" $$SPACES "" "$$HEADER6"; \
	echo ""; \
	echo "$$BORDER"; \
    SPACES=$$((($$COLUMNS-43)/2)); printf "%*s%s\n" $$SPACES "" "COMMANDS FOR GO PROJECT MANAGEMENT"; \
	echo "$$BORDER"; \
	echo "  SOURCE: https://github.com/sss7526/go_maker"; \
	echo ""; \
	echo "  SETUP AND MAINTENANCE:"; \
	echo "      install       Install the latest Go version (if not installed)."; \
	echo "      update        Update Go to the latest version (if needed)."; \
	echo "      uninstall     Remove the currently installed Go version."; \
	echo ""; \
	echo "  MODULE MANAGEMENT:"; \
	echo "      mod-init      Initialize a new Go module in the current directory."; \
	echo "      mod-tidy      Ensure go.mod and go.sum are in a tidy state."; \
	echo "      mod-update    Update all project dependencies to their latest versions."; \
	echo ""; \
	echo "  CODE QUALITY & SECURITY:"; \
	echo "      format        Format Go files to a consistent standard (via gofmt)."; \
	echo "      lint          Perform rigorous code linting with golangci-lint."; \
	echo "      vulncheck     Analyze dependencies for vulnerabilities (via govulncheck)."; \
	echo ""; \
	echo "  BUILD, RUN, & TEST:";\
	echo "      run           Run the project's main entry point (main.go)"; \
	echo "      test          Run all tests recursively across all packages."; \
	echo "      build         Build the project and output the binary to $(LOCAL_BIN)$(MODULE_NAME)."; \
	echo "      build-dev     Build the project in dev mode and output the binary to $(LOCAL_BIN)$(MODULE_NAME)."; \
	echo "      ex            Execute the built binary."; \
	echo "      clean         Remove the compiled binary from $(LOCAL_BIN)."; \
	echo ""; \
	echo "  MISCELLANEOUS:"; \
	echo "      fix_certs     Fix TLS certificate issues when working in WSL in Enterprise Windows environments."; \
	echo "      tree          Generate a directory structure summary and save it to tree.txt."; \
	echo "      doctor        Check for missing system utilities."; \
	echo "      help          Display this help screen."; \
	echo ""; \
	echo "$$BORDER"; \
	SPACES=$$((($$COLUMNS-38)/2)); printf "%*s%s\n" $$SPACES "" "INFO: Use 'make <target>' to run a command."; \
	echo "$$BORDER"; \
	echo ""

## Validate Go is installed
.validate_go_installed:
	@if [ "$(GO_CURRENT_VERSION)" = "none" ]; then \
		$(call ERROR,Go is not installed. Please install Go first using 'make install'.); \
		exit 1; \
	fi

## Validate latest version of Go
.validate_latest:
	@if [ "$(LATEST_GO_VERSION)" = "" ]; then \
		$(call ERROR,Unable to fetch the latest Go version. Check your internet connection or the Go website.); \
		exit 1; \
	fi
	@if ! echo "$(LATEST_GO_VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$'; then \
		$(call ERROR,Detected invalid Go version format ('$(LATEST_GO_VERSION)'). Please check the Go website or your internet connection.); \
		exit 1; \
    fi

## Ensure GOPATH and $GOPATH/bin in PATH
.validate_gopath:
	@if [ "$(GOPATH)" = "" ]; then \
		$(call WARNING,GOPATH is not set. Defaulting to $(HOME)/go.); \
	fi
	@if ! echo $$PATH | grep -q "$(GOPATH)/bin"; then \
		$(call INFO,Adding $(GOPATH)/bin to PATH via ~/.bashrc...); \
		grep -qxF 'export PATH=$${PATH}:$(GOPATH)/bin' ~/.bashrc || echo 'export PATH=$${PATH}:$(GOPATH)/bin' >> ~/.bashrc; \
		$(call SUCCESS,Updated PATH to include $(GOPATH)/bin. Please run 'source ~/.bashrc' or restart your shell to apply changes.); \
	fi

.validate_local_bin_path:
	@if ! echo $$PATH | grep -q "$(LOCAL_BIN)"; then \
		$(call INFO,Adding $(LOCAL_BIN) to PATH via ~/.bashrc...); \
		grep -qxF 'export PATH=$$PATH:$(LOCAL_BIN)' ~/.bashrc || echo 'export PATH=$$PATH:$(LOCAL_BIN)' >> ~/.bashrc; \
		$(call SUCCESS,Updated PATH to include $(LOCAL_BIN). Please run 'source ~/.bashrc' or restart your shell to apply changes.); \
	else \
		$(call INFO,$(LOCAL_BIN) is already in PATH.); \
	fi

## Install the latest Go version if not already installed
install: .validate_latest .validate_gopath .validate_local_bin_path
	@if [ "$(GO_CURRENT_VERSION)" != "none" ] && [ "$(GO_CURRENT_VERSION)" != "$(LATEST_GO_VERSION)" ]; then \
		$(call WARNING,An older version of Go ($(GO_CURRENT_VERSION)) is already installed.); \
		$(call WARNING,Please run 'make update' to safely upgrade to Go $(LATEST_GO_VERSION).); \
		exit 1; \
	elif [ "$(GO_CURRENT_VERSION)" = "$(LATEST_GO_VERSION)" ]; then \
		$(call SUCCESS,The latest version of Go ($(LATEST_GO_VERSION)) is already installed. No update required.); \
	else \
		$(call INFO,Installing Go $(LATEST_GO_VERSION)...); \
		curl -OL $(GO_URL)$(GO_TARBALL) || { \
			$(call ERROR,Failed to download Go tarball. Check your internet connection or run 'make fix_certs.'); \
			exit 1; \
		}; \
		sudo tar -C $(GO_INSTALL_DIR) -xzf $(GO_TARBALL) || { \
			$(call ERROR,Failed to extract Go tarball. Check permissions. Requires sudo.); \
			exit 1; \
		}; \
		rm $(GO_TARBALL); \
		grep -qxF 'export PATH=$${PATH}:$(GO_INSTALL_DIR)/go/bin' ~/.bashrc || echo 'export PATH=$${PATH}:$(GO_INSTALL_DIR)/go/bin' >> ~/.bashrc; \
		$(call SUCCESS,Installation complete. Please run 'source ~/.bashrc' or restart your shell to apply changes.); \
	fi

## Update Go to the latest version (removing previous installation if necessary)
update: .validate_latest .validate_gopath
	@if [ "$(GO_CURRENT_VERSION)" = "$(LATEST_GO_VERSION)" ]; then \
		$(call SUCCESS,The latest version of Go ($(LATEST_GO_VERSION)) is already installed. No update required.); \
	elif [ "$(GO_CURRENT_VERSION)" = "none" ]; then \
		$(call WARNING,No Go version is currently installed. Please run 'make install'); \
	else \
		$(MAKE) uninstall; \
		$(MAKE) install; \
	fi

## Remove currently installed Go version
uninstall:
	@if [ "$(GO_CURRENT_VERSION)" != "none" ]; then \
		$(call WARNING,Removing Go $(GO_CURRENT_VERSION)...); \
		sudo rm -rf $(GO_INSTALL_DIR)/go; \
		sed -i '/go\/bin/d' ~/.bashrc; \
		sed -i '/$(ESCAPED_GOPATH)\/bin/d' ~/.bashrc; \
		$(call SUCCESS,Go $(GO_CURRENT_VERSION) has been removed. Please run 'source ~/.bashrc' or restart your shell to apply changes.); \
	else \
		$(call WARNING,No Go installation found to remove.); \
	fi

## Install golangci-ling
golangci-lint-install: .validate_go_installed
	@if ! command -v $(GOLANGCI_LINT_BINARY) >/dev/null 2>&1; then \
		$(call INFO,Installing golangci-lint...); \
		go install $(LINT_PACKAGE)@latest; \
	else \
		$(call WARNING,golang-lint already installed.); \
	fi

## Run golangci-ling for linting and static analysis
lint: golangci-lint-install format
	@$(call INFO,Running golangci-lint with comprehensive checks...); \
	$(GOLANGCI_LINT_BINARY) run --verbose --disable-all \
		--enable=errcheck \
		--enable=gosimple \
		--enable=govet \
		--enable=ineffassign \
		--enable=staticcheck \
		--enable=unused \
		--enable=gosec \
		--timeout=5m

## Install govulncheck
govulncheck-install: .validate_go_installed
	@if ! command -v $(GOVULNCHECK_BINARY) >/dev/null 2>&1; then \
		$(call INFO,Installing govulncheck...); \
		go install $(VULNCHECK_PACKAGE)@latest; \
	else \
		$(call WARNING,govulncheck is already installed.); \
	fi

## Run govulncheck for dependency vulnerability scans
vulncheck: govulncheck-install
	@$(call INFO,Running govulncheck vulnerability scan in verbose mode...); \
	$(GOVULNCHECK_BINARY) -show verbose ./...


.generate-go-mod:
	@if [ ! -f go.mod ]; then \
		$(call INFO,Initializing Go module with name: $(MODULE_NAME)...); \
		go mod init $(MODULE_NAME); \
		$(call SUCCESS,go.mod created.); \
	else \
		$(call WARNING,go.mod already exists. Skipping go mod init.); \
	fi

.generate-main-go:
	@if [ ! -f main.go ]; then \
		$(call INFO,Creating main.go with a Hello World program...); \
		printf "%s\n" \
		"package main" \
		"" \
		"import \"fmt\"" \
		"" \
		"func main() {" \
		"    fmt.Println(\"Hello, World!\")" \
		"}" > main.go; \
		$(call SUCCESS,main.go created.); \
	else \
		$(call WARNING,main.go already exists. Skipping creation.); \
	fi

.generate-main-test-go:
	@if [ ! -f main_test.go ]; then \
		$(call INFO,Creating main_test.go with a basic test...); \
		printf "%s\n" \
		"package main" \
		"" \
		"import (" \
		"    \"testing\"" \
		"    \"os\"" \
		"    \"io\"" \
		"    \"bytes\"" \
		")" \
		"" \
		"func TestMainProgram(t *testing.T) {" \
		"    // Capture standard output" \
		"    r, w, _ := os.Pipe()" \
		"    stdout := os.Stdout" \
		"    os.Stdout = w" \
		"    defer func() { os.Stdout = stdout }()" \
		"" \
		"    main()" \
		"" \
		"    // Close the pipe and read the output" \
		"    w.Close()" \
		"    var buf bytes.Buffer" \
		"    io.Copy(&buf, r)" \
		"    r.Close()" \
		"" \
		"    // Verify output" \
		"    expected := \"Hello, World!\\n\"" \
		"    actual := buf.String()" \
		"    if actual != expected {" \
		"        t.Errorf(\"Expected %q but got %q\", expected, actual)" \
		"    }" \
		"}" > main_test.go; \
		$(call SUCCESS,main_test.go created.); \
	else \
		$(call WARNING,main_test.go already exists. Skipping creation.); \
	fi

.initialize-git:
	@if [ -d .git ]; then \
		if git remote get-url origin 2>/dev/null | grep -q "^$(TEMPLATE_REPO_URL)$$"; then \
			$(call WARNING,The repository is currently linked to the template upstream ($(TEMPLATE_REPO_URL)).); \
			$(call INFO,Resetting .git and initializing a new Git repository...); \
			rm -rf .git; \
			[ -f LICENSE ] && rm LICENSE; \
			[ -f README.md ] && rm README.md; \
			git init -b main; \
			$(call SUCCESS,Git repository has been reset and initialized.); \
		else \
			$(call INFO,The repository is not linked to the original go_maker template upstream. Skipping Git reset.); \
		fi \
	else \
		$(call INFO,No .git directory found. Initializing a new Git repository...); \
		git init -b main; \
		[ -f LICENSE ] && rm LICENSE; \
		[ -f README.md ] && rm README.md; \
		$(call SUCCESS,New Git repository initialized.); \
	fi

## Initialize a new Go project in the current directory
mod-init: .validate_go_installed .generate-go-mod .generate-main-go .generate-main-test-go .initialize-git

## Clean up go.mod and go.sum files
mod-tidy: .validate_go_installed
	@$(call INFO,Tidying up go.mod and go.sum...); \
	go mod tidy

## Update all dependencies to the latest compatible versions
mod-update: .validate_go_installed
	@$(call INFO,Updating all dependences to the latest compatible versions...); \
	if ! go get -u ./...; then \
		$(call ERROR,Dependency update failed. Check internet connection or potential TLS issues.\nTry running 'make fix_certs.'); \
		exit 1; \
	fi
	@$(call INFO,Running go mod tidy to clean up dependences...); \
	if ! go mod tidy; then \
		$(call ERROR,go mod tidy failed. Check internet connection or potential TLS issues.\nTry running 'make fix_certs.'); \
		exit 1; \
	fi
format: .validate_go_installed
	@$(call INFO,Formatting Go files using gofmt...); \
	go fmt ./...

run: .validate_go_installed
	@go run . $(filter-out $@,$(MAKECMDGOALS))

test: .validate_go_installed
	@go test ./...

build: .validate_go_installed
	@$(call INFO,Building $(LOCAL_BIN)$(MODULE_NAME))
	go build -o $(LOCAL_BIN)$(MODULE_NAME) -ldflags "-w -s -extldflags '-static'" -trimpath .

build-dev: .validate_go_installed
	@$(call INFO,Building $(LOCAL_BIN)$(MODULE_NAME))
	go build -o $(LOCAL_BIN)$(MODULE_NAME) .

ex:
	@$(MODULE_NAME) $(filter-out $@,$(MAKECMDGOALS))

tree:
	@$(call INFO,Printing project structure to treefile...)
	@if ! tree -n --dirsfirst -I "Makefile|tree.txt" -o tree.txt; then \
		$(call ERROR,Tree command failed. Probably need to install it.\nRun 'make doctor' to check for missing system tools.); \
	fi

clean:
	@if [ -f "$(LOCAL_BIN)$(MODULE_NAME)" ]; then \
		$(call INFO,Removing binary from $(LOCAL_BIN)$(MODULE_NAME));\
		rm $(LOCAL_BIN)$(MODULE_NAME); \
		$(call SUCCESS,Binary successfully removed.); \
	else \
		$(call WARNING,No binary found at $(LOCAL_BIN)$(MODULE_NAME). Nothin to clean.); \
	fi

fix_certs:
	@$(call INFO,Fetching TLS certificates for the following domains: $(DOMAINS))
	@$(foreach DOMAIN, $(DOMAINS), \
		echo  "Fetching certificate for $(DOMAIN)" && \
		curl -s --show-error --retry 3 --insecure "https://$(DOMAIN)" 1>/dev/null && \
		echo | openssl s_client -showcerts -connect $(DOMAIN):443 -servername $(DOMAIN) 2>/dev/null | \
		openssl x509 -outform PEM -out "$(DOMAIN).crt" && \
		sudo mv "$(DOMAIN).crt" $(CERT_DIR)/ && \
		echo "Certificate for $(DOMAIN) saved to $(CERT_DIR)/$(DOMAIN).crt"; \
	)
	@$(call INFO,Updating CA certificates...)
	@sudo update-ca-certificates
	@$(call SUCCESS,Certificates updated successfully)

## Check for required system tools and their packages
doctor:
	@$(call INFO,Running system tools check...)
	@tools="\
		curl=curl\n\
		openssl=openssl\n\
		git=git\n\
		tree=tree\n\
		awk=gawk\n\
		grep=grep\n\
		sed=sed\n\
		update-ca-certificates=ca-certificates\n\
		rm=coreutils\n\
		tar=tar"; \
	echo -e "$$tools" | while IFS="=" read -r tool package; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			$(call ERROR,"$$tool is missing."); \
			echo "Install with: sudo apt update && sudo apt install -y $$package"; \
		else \
			$(call SUCCESS,"$$tool is installed."); \
		fi; \
	done
	@$(call INFO,System tools check complete.)

# Prevents make from treating arbitrary arguments as make targets
%:
	@true