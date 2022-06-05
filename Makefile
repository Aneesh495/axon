CXX ?= clang++
PYTHON ?= python3

all: build

build:
	@echo "Building Axon C++ native runtime engine..."
	$(MAKE) -C runtime
	@chmod +x bin/axon

test:
	@echo "Running full test suites..."
	$(PYTHON) harness/runner.py

typecheck:
	@echo "Running Hack static type analysis..."
	$(PYTHON) harness/typecheck.py

lint:
	@echo "Enforcing zero em-dash policy across all files..."
	$(PYTHON) scripts/check_no_em_dash.py

bench:
	@echo "Running Axon benchmarks..."
	$(PYTHON) harness/bench.py 50000
	@bin/axon native bench

clean:
	@echo "Cleaning build artifacts..."
	$(MAKE) -C runtime clean
	rm -rf build bin/axon-runtime

.PHONY: all build test typecheck lint bench clean
