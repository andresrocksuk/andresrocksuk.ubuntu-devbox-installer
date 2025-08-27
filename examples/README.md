# WSL Installation System - Examples

This directory contains practical examples and use cases for the WSL Declarative Installation System.

## 📁 Example Configurations

### Minimal Developer Setup
See: `minimal-dev.yaml` - A lightweight setup for basic development

### Data Science Environment  
See: `data-science.yaml` - Python-focused setup with data analysis tools

### DevOps Toolkit
See: `devops.yaml` - Complete DevOps and cloud tools installation

### Custom Enterprise Setup
See: `enterprise.yaml` - Enterprise-focused tools and configurations

## 🛠️ Custom Installation Scripts

### Adding New Software
See: `software-scripts/example-tool/` - Template for creating new installation scripts

### Complex Dependencies
See: `software-scripts/complex-example/` - Handling software with complex dependencies

## 🧪 Testing Examples

### Custom Test Scripts
See: `test-examples/` - Examples of custom verification and testing

## 📚 Usage Patterns

### Selective Installation
Examples of running partial installations for specific use cases

### CI/CD Integration
Examples of using the system in automated environments

### Multi-Environment Management
Managing different configurations for different environments

## 📋 Log Management

### View Run Logs
See: `view-run-logs.sh` - Script to view logs for specific installation runs

Each installation run creates multiple files with the same run ID timestamp:
- `wsl-installation-RUNID.log` - Main installation log
- `installation-report-RUNID.txt` - Version and system report
- `test-results-RUNID.txt` - Test results (if tests are run)

**Examples:**
```bash
# List all available runs
./examples/view-run-logs.sh

# View logs for specific run
./examples/view-run-logs.sh 20250823_143022

# View logs for most recent run
./examples/view-run-logs.sh latest
```
