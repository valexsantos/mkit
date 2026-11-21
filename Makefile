.PHONY: help build install test lint console server clean all

help:
	@echo "MKIt - available targets:"
	@echo ""
	@echo "  make build    - Build the gem (rake package)"
	@echo "  make install  - Build and install the gem locally"
	@echo "  make test     - Run specs in spec/ (Minitest)"
	@echo "  make lint     - Run RuboCop on lib/ and bin/"
	@echo "  make console  - Open a Pry console (rake console)"
	@echo "  make server   - Run mkitd in development (no ssl, ./config)"
	@echo "  make clean    - Remove built gems"
	@echo "  make all      - lint, test and build"
	@echo ""

build:
	bundle exec rake package

install:
	bundle exec rake install

test:
	@for f in spec/*_spec.rb; do \
		echo "== $$f"; \
		RACK_ENV=test bundle exec ruby -Ispec $$f || exit 1; \
	done

lint:
	bundle exec rubocop lib/ bin/

console:
	bundle exec rake console

server:
	bundle exec bin/mkitd --no-ssl -e development

clean:
	rm -f mkit-*.gem

all: lint test build

.DEFAULT_GOAL := help
