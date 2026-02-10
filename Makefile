.PHONY: help setup clean test test-unit test-data build run seed deps lint docs

# Default target
help:
	@echo "GrowthCues Core - Development Commands"
	@echo ""
	@echo "Setup & Dependencies:"
	@echo "  make setup          - Full setup: install deps + seed data"
	@echo "  make deps           - Install dbt dependencies (dbt deps)"
	@echo "  make seed           - Load seed data into dev database"
	@echo ""
	@echo "Building:"
	@echo "  make build          - Build all models and run all tests"
	@echo "  make run            - Run all models (without tests)"
	@echo "  make run-staging    - Run only staging models"
	@echo "  make run-marts      - Run only marts models"
	@echo ""
	@echo "Testing:"
	@echo "  make test           - Run all tests (unit + data quality)"
	@echo "  make test-unit      - Run only unit tests"
	@echo "  make test-data      - Run only data quality tests"
	@echo "  make test-sessions  - Run sessionization tests"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean          - Clean compiled/run artifacts (dbt clean)"
	@echo "  make clean-all      - Clean everything including dependencies"
	@echo ""
	@echo "Documentation:"
	@echo "  make docs           - Generate and serve documentation"
	@echo "  make docs-generate  - Generate documentation only"
	@echo ""
	@echo "Development:"
	@echo "  make lint           - Check SQL style/formatting"
	@echo "  make fresh          - Clean + setup + build (fresh start)"

# Setup & Dependencies
setup: deps seed
	@echo "✓ Setup complete! Run 'make build' to build models."

deps:
	@echo "Installing dbt dependencies..."
	dbt deps --target dev

seed:
	@echo "Loading seed data..."
	dbt seed --target dev

# Building
build:
	@echo "Building all models and running tests..."
	dbt build --target dev

run:
	@echo "Running all models..."
	dbt run --target dev

run-staging:
	@echo "Running staging models..."
	dbt run --select staging --target dev

run-marts:
	@echo "Running marts models..."
	dbt run --select marts --target dev

# Testing
test:
	@echo "Running all tests..."
	dbt test --target dev

test-unit:
	@echo "Running unit tests..."
	dbt test --select test_type:unit --target dev

test-data:
	@echo "Running data quality tests..."
	dbt test --exclude test_type:unit --target dev

test-sessions:
	@echo "Running sessionization tests..."
	dbt test --select fct_sessions --target dev

# Documentation
docs:
	@echo "Generating and serving documentation..."
	dbt docs generate --target dev
	dbt docs serve

docs-generate:
	@echo "Generating documentation..."
	dbt docs generate --target dev

# Cleanup
clean:
	@echo "Cleaning compiled artifacts..."
	dbt clean

clean-all: clean
	@echo "Removing dependencies..."
	rm -rf dbt_packages
	rm -rf logs

# Development shortcuts
fresh: clean-all setup build
	@echo "✓ Fresh build complete!"

lint:
	@echo "Note: Install sqlfluff for SQL linting"
	@echo "  pip install sqlfluff sqlfluff-templater-dbt"
	@echo "  sqlfluff lint models/"

# CI/CD targets
ci-test: deps test-unit
	@echo "✓ CI tests passed!"

ci-build: deps build
	@echo "✓ CI build complete!"
