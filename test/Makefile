.PHONY: test test-fast test-backend test-networking test-eks clean

# Run all tests
test:
	@echo "Running all Terratest tests..."
	go test -v -timeout 30m

# Run tests without cleanup (faster for development)
test-fast:
	@echo "Running fast tests (validation only)..."
	go test -v -timeout 10m -short

# Run specific module tests
test-backend:
	@echo "Testing backend module..."
	go test -v -timeout 10m -run TestTerraformBackend

test-networking:
	@echo "Testing networking module..."
	go test -v -timeout 10m -run TestTerraformNetworking

test-eks:
	@echo "Testing EKS module..."
	go test -v -timeout 10m -run TestTerraformEKS

# Initialize Go modules
init:
	@echo "Initializing Go modules..."
	go mod download
	go mod tidy

# Clean test cache
clean:
	@echo "Cleaning test cache..."
	go clean -testcache
