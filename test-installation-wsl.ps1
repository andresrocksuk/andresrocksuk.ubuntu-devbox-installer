[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu-24.04",
    [ValidateSet("basic", "security", "support-url", "installation", "nix", "all")]
    [string]$TestType = "all"
)

<#
.SYNOPSIS
    PowerShell wrapper for WSL installation testing

.DESCRIPTION
    This script runs various test suites for the WSL Ubuntu DevBox Installer from within WSL.
    It provides a Windows-friendly interface to execute bash test scripts.

.PARAMETER Distribution
    The WSL distribution to use for testing (default: Ubuntu-24.04)

.PARAMETER TestType
    The type of test to run: basic, security, support-url, installation, nix, or all

.EXAMPLE
    .\test-installation-wsl.ps1
    Run all test suites

.EXAMPLE
    .\test-installation-wsl.ps1 -TestType security
    Run only security tests

.EXAMPLE
    .\test-installation-wsl.ps1 -Distribution "Ubuntu-22.04" -TestType basic
    Run basic tests on Ubuntu 22.04
#>

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Convert Windows path to WSL path
$wslSourcePath = $PSScriptRoot -replace "C:", "/mnt/c" -replace "\\", "/"

Write-Info "WSL Installation Testing Script"
Write-Info "==============================="
Write-Info "Distribution: $Distribution"
Write-Info "Test Type: $TestType"
Write-Info "Source Path: $wslSourcePath"
Write-Info ""

# Function to run a specific test
function Run-Test {
    param(
        [string]$TestName,
        [string]$TestScript
    )
    
    Write-Info "Running $TestName tests..."
    Write-Info "Command: wsl --user root --distribution $Distribution -- bash -c 'cd $wslSourcePath/src/tests && bash $TestScript'"
    
    try {
        $result = wsl --user root --distribution $Distribution -- bash -c "cd $wslSourcePath/src/tests && bash $TestScript"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "$TestName tests completed successfully"
            return $true
        } else {
            Write-Error "$TestName tests failed with exit code: $LASTEXITCODE"
            return $false
        }
    }
    catch {
        Write-Error "$TestName tests failed with exception: $($_.Exception.Message)"
        return $false
    }
}

# Run tests based on TestType parameter
$testResults = @{}

switch ($TestType) {
    "basic" {
        $testResults["Basic"] = Run-Test "Basic Functionality" "test-basic-functionality.sh"
    }
    "security" {
        $testResults["Security"] = Run-Test "Security" "test-security.sh"
    }
    "support-url" {
        $testResults["Support URL"] = Run-Test "Support URL Feature" "test-support-url-feature.sh"
    }
    "installation" {
        $testResults["Installation"] = Run-Test "Installation Verification" "test-installation.sh"
    }
    "nix" {
        $testResults["Nix"] = Run-Test "Nix Installation" "test-nix-installation.sh"
    }
    "all" {
        Write-Info "Running comprehensive test suite..."
        $testResults["Basic"] = Run-Test "Basic Functionality" "test-basic-functionality.sh"
        $testResults["Security"] = Run-Test "Security" "test-security.sh"
        $testResults["Support URL"] = Run-Test "Support URL Feature" "test-support-url-feature.sh"
        $testResults["Installation"] = Run-Test "Installation Verification" "test-installation.sh"
        $testResults["Nix"] = Run-Test "Nix Installation" "test-nix-installation.sh"
    }
    default {
        Write-Error "Invalid test type: $TestType"
        exit 1
    }
}

# Display test summary
Write-Info ""
Write-Info "Test Summary"
Write-Info "============"

$passedTests = 0
$totalTests = $testResults.Count

foreach ($test in $testResults.GetEnumerator()) {
    if ($test.Value) {
        Write-Success "✓ $($test.Key) tests passed"
        $passedTests++
    } else {
        Write-Error "✗ $($test.Key) tests failed"
    }
}

Write-Info ""
Write-Info "Overall Results: $passedTests/$totalTests tests passed"

if ($passedTests -eq $totalTests) {
    Write-Success "All tests passed successfully!"
    exit 0
} else {
    Write-Error "Some tests failed. Check the output above for details."
    exit 1
}
