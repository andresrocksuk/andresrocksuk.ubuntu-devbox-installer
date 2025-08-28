# WSL Ubuntu DevBox Remote Installer

param(
    [switch]$ResetWSL,
    [switch]$Force,
    [string[]]$Config = @(),
    [string]$BranchName = "main",
    [switch]$Help
)

# Display help information
if ($Help) {
    Write-Host @"
WSL Ubuntu DevBox Remote Installer

BASIC USAGE:
    irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/$BranchName/install-wsl-remote.ps1" | iex

BASIC ADVANCED USAGE:
    & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/$BranchName/install-wsl-remote.ps1")))

PARAMETERS:
    -ResetWSL    Reset WSL distribution before installation (WARNING: This will delete existing WSL data)
    -Force       Force installation without confirmation prompts (WARNING: This will skip all confirmations)
    -Config      Specify installation section from the install.yaml configuration (e.g., @("apt_packages") or @("custom_software"))
    -BranchName  Specify the branch name to use from the GitHub repository (default: "main")
    -Help        Show this help message

EXAMPLES:
    # Basic installation
    irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/$BranchName/install-wsl-remote.ps1" | iex

    # Installation with WSL reset (Advanced)
    & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/$BranchName/install-wsl-remote.ps1"))) -ResetWSL

    # Installation with minimal development configuration
    & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/$BranchName/install-wsl-remote.ps1"))) -Config @("apt_packages")

"@ -ForegroundColor Green
    return
}

# Function to write colored output
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main installation function
function Start-RemoteInstallation {
    Write-ColoredOutput "🚀 WSL Ubuntu DevBox Remote Installer" "Cyan"
    Write-ColoredOutput "========================================" "Cyan"
    
    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-ColoredOutput "❌ This script requires administrator privileges." "Red"
        Write-ColoredOutput "Please run PowerShell as Administrator and try again." "Yellow"
        return
    }

    # Repository information
    $branchNameClean = $BranchName.Replace('/', '-')
    $branchLastPath = $BranchName.Split('/')[-1]
    $zipUrl = "https://github.com/andresrocksuk/andresrocksuk.ubuntu-devbox-installer/archive/refs/heads/$BranchName.zip"
    
    # Create temporary directory
    $tempDir = Join-Path $env:TEMP "ubuntu-devbox-installer-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-ColoredOutput "📁 Creating temporary directory: $tempDir" "Yellow"
    
    try {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Download the repository
        Write-ColoredOutput "⬇️  Downloading latest version from GitHub..." "Yellow"
        $zipPath = Join-Path $tempDir "$branchLastPath.zip"
        
        # Use WebClient for better compatibility
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($zipUrl, $zipPath)
        
        Write-ColoredOutput "✅ Download completed successfully" "Green"
        
        # Extract the archive
        Write-ColoredOutput "📦 Extracting archive..." "Yellow"
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        
        # Navigate to the extracted directory
        $extractedDir = Join-Path $tempDir "andresrocksuk.ubuntu-devbox-installer-$branchNameClean"
        
        if (-not (Test-Path $extractedDir)) {
            throw "Extracted directory not found: $extractedDir"
        }
        
        Set-Location $extractedDir
        Write-ColoredOutput "✅ Repository extracted successfully" "Green"
        
        # Prepare installation arguments
        $installArgs = @{
            AutoInstall = $true
            ResetWSL = $false
            RunDirect = $false
            Force = $false
            Config = @()
        }
        
        if ($ResetWSL) {
            $installArgs.ResetWSL = $true
            Write-ColoredOutput "⚠️  WARNING: WSL will be reset (existing data will be lost)" "Red"
        }

        if ($Force) {
            $installArgs.Force = $true
            Write-ColoredOutput "⚠️  WARNING: Installation will not require confirmation" "Red"
        }
        
        if ($Config) {
            $installArgs.Config = $Config
            Write-ColoredOutput "🔧 Using configuration: $Config" "Yellow"
        }
        
        # Execute the installation script
        Write-ColoredOutput "🔄 Starting WSL Ubuntu DevBox installation..." "Cyan"
        Write-ColoredOutput "Arguments: $($installArgs | ConvertTo-Json)" "Yellow"
        
        $installScript = Join-Path $extractedDir "install-wsl.ps1"
        
        if (-not (Test-Path $installScript)) {
            throw "Installation script not found: $installScript"
        }
        
        # Execute the installation
        & $installScript @installArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColoredOutput "🎉 WSL Ubuntu DevBox installation completed successfully!" "Green"
        } else {
            Write-ColoredOutput "❌ Installation completed with errors. Check the logs for details." "Red"
        }
        
    } catch {
        Write-ColoredOutput "❌ Error during installation: $($_.Exception.Message)" "Red"
        Write-ColoredOutput "Please check your internet connection and try again." "Yellow"
        return
    } finally {
        # Cleanup
        Write-ColoredOutput "🧹 Cleaning up temporary files..." "Yellow"
        try {
            Set-Location $env:TEMP
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-ColoredOutput "✅ Cleanup completed" "Green"
        } catch {
            Write-ColoredOutput "⚠️  Warning: Could not clean up temporary directory: $tempDir" "Yellow"
        }
    }
}

# Execute the installation
$LASTEXITCODE = $null
Start-RemoteInstallation
