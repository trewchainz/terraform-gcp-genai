# Terraform Tests

This directory contains Terraform test files for validating the GCP GenAI infrastructure configuration.

## Test Files

- **`main.tftest.hcl`** - Comprehensive test suite covering all infrastructure components
- **`security.tftest.hcl`** - Security-focused tests for IAM, encryption, and compliance

## Running Tests

### Run All Tests
```bash
terraform test
```

### Run Specific Test File
```bash
terraform test -filter=tests/security.tftest.hcl
```

### Run Specific Test
```bash
terraform test -filter=validate_vpc_network
```

### Verbose Output
```bash
terraform test -verbose
```

## Test Coverage

### Main Test Suite (`main.tftest.hcl`)
- ✅ VPC network configuration
- ✅ Subnet configuration and flow logs
- ✅ Cloud Run security settings
- ✅ IAM least privilege
- ✅ Encryption at rest (CMEK)
- ✅ Secret management
- ✅ Monitoring and alerting
- ✅ Firewall rules
- ✅ Resource naming conventions
- ✅ AlloyDB configuration
- ✅ VPC Service Controls
- ✅ Environment-specific settings
- ✅ API enablement
- ✅ Storage lifecycle
- ✅ Resource labeling

### Security Test Suite (`security.tftest.hcl`)
- ✅ No public Cloud Run access
- ✅ IAP configuration
- ✅ Egress traffic control
- ✅ No hardcoded secrets
- ✅ KMS key rotation
- ✅ Service account permissions
- ✅ Audit logging
- ✅ VPC Flow Logs
- ✅ Storage bucket privacy
- ✅ NAT logging
- ✅ Security monitoring topics
- ✅ DLP configuration
- ✅ Database backup retention
- ✅ Security function IAM

## Test Requirements

1. **Terraform Version**: >= 1.6.0 (for native test support)
2. **No GCP Credentials Required**: Tests use mock providers
3. **No State File**: Tests run in plan mode only

## Test Structure

Each test follows this pattern:

```hcl
run "test_name" {
  command = plan  # or apply for integration tests

  # Optional: Override variables
  variables {
    environment = "prod"
  }

  # Assertions
  assert {
    condition     = <boolean expression>
    error_message = "Descriptive error message"
  }
}
```

## Best Practices

1. **Test in CI/CD**: Run `terraform test` in your CI/CD pipeline
2. **Test Before Apply**: Always run tests before `terraform apply`
3. **Update Tests**: Update tests when changing infrastructure
4. **Document Failures**: If a test fails, document why and fix the issue

## Common Test Patterns

### Testing Resource Existence
```hcl
assert {
  condition     = resource.type.name != null
  error_message = "Resource should exist"
}
```

### Testing Resource Attributes
```hcl
assert {
  condition     = resource.type.name.attribute == "expected_value"
  error_message = "Attribute should match expected value"
}
```

### Testing Collections
```hcl
assert {
  condition     = length(resource.type.name) > 0
  error_message = "Collection should not be empty"
}
```

### Testing Conditionals
```hcl
assert {
  condition     = var.condition ? length(resource.type.name) == 1 : length(resource.type.name) == 0
  error_message = "Resource should exist only when condition is true"
}
```

## Troubleshooting

### Test Fails with "Resource not found"
- Check that the resource name matches exactly
- Verify the resource is created in the current configuration

### Test Fails with "Invalid condition"
- Check the condition syntax
- Verify attribute paths are correct
- Use `terraform console` to test expressions

### Mock Provider Issues
- Ensure mock providers are defined at the top of test files
- Check that provider aliases match

## Adding New Tests

1. Create a new `run` block in the appropriate test file
2. Use descriptive test names (e.g., `validate_encryption_enabled`)
3. Add clear error messages
4. Test both positive and negative cases
5. Update this README with new test coverage

## Example: Adding a Custom Test

```hcl
run "validate_custom_requirement" {
  command = plan

  assert {
    condition     = <your_condition>
    error_message = "Clear description of what failed"
  }
}
```
