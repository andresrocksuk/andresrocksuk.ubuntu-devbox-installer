[CmdletBinding()]
param(
    [switch]$AutoInstall,
    [switch]$Force,
    [switch]$ResetWSL,
    [switch]$RunDirect,
    [string]$Distribution = "Ubuntu-24.04",
    [string]$InstallPath = (Join-Path $PSScriptRoot "src"),
    [string[]]$Config = @()
)

<#
.SYNOPSIS
    WSL Installation and Management Script

.DESCRIPTION
    This script manages WSL installations and can optionally reset WSL distributions.
    By default, it uses existing WSL installations unless -ResetWSL is specified.

.PARAMETER AutoInstall
    Automatically run the installation script after WSL setup and prompt for user creation

.PARAMETER Force
    Skip confirmation prompts and use default values for user creation (use with caution)

.PARAMETER ResetWSL
    Unregister and reinstall the WSL distribution (destructive operation)

.PARAMETER RunDirect
    Run the installation directly from the mounted install.sh script instead of copying to temp directory for better performance. This may be slower but avoids disk space usage.

.PARAMETER Distribution
    The WSL distribution to install/use (default: Ubuntu-24.04)

.PARAMETER InstallPath
    Path to the installation scripts (default: current script directory)

.PARAMETER Config
    Specify one or more configuration sections to run. Available sections: prerequisites, apt_packages, shell_setup, custom_software, python_packages, powershell_modules, nix_packages, configurations. If not specified, all sections will be run.

.EXAMPLE
    .\install-wsl.ps1 -AutoInstall
    Run installation script and prompt for username/password to create default user

.EXAMPLE
    .\install-wsl.ps1 -ResetWSL -AutoInstall -Force
    Reset WSL, run installation script, and create default user without prompts

.EXAMPLE
    .\install-wsl.ps1 -ResetWSL
    Only reset WSL without running installation script

.EXAMPLE
    .\install-wsl.ps1 -AutoInstall -Config "prerequisites","apt_packages"
    Run only prerequisites and apt_packages sections and create default user

.EXAMPLE
    .\install-wsl.ps1 -AutoInstall -RunDirect
    Run installation directly from mounted script without copying to temp directory

.EXAMPLE
    .\install-wsl.ps1 -AutoInstall -Config "custom_software"
    Run only the custom_software section and create default user

.EXAMPLE
    $env:WSL_DEFAULT_PASSWORD = "mypassword"; .\install-wsl.ps1 -AutoInstall -Force
    Use environment variable for password when Force mode is used
#>

# WSL Installation and Management Script
# This script can install WSL, reset WSL distributions, and run installation scripts

# Set error action preference
$ErrorActionPreference = "Stop"

# Global variables for spinner clearing
$script:ClearSpinnerLine = "`r" + (" " * 80) + "`r"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to write info message
function Write-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" -Color "Cyan"
}

# Function to write success message
function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[SUCCESS] $Message" -Color "Green"
}

# Function to write warning message
function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" -Color "Yellow"
}

# Function to write error message
function Write-ErrorMessage {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" -Color "Red"
}

# Function to check if running as administrator
function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check WSL status
function Get-WSLStatus {
    try {
        $wslVersion = wsl --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            return @{
                Installed = $true
                Version = $wslVersion
            }
        }
    }
    catch {
        # WSL not installed or not working
    }
    
    return @{
        Installed = $false
        Version = $null
    }
}

# Function to get installed distributions
function Get-WSLDistributions {
    try {
        $distributions = wsl --list --verbose 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $distributions
        }
    }
    catch {
        # WSL not available
    }
    
    return @()
}

# Function to uninstall WSL distribution
function Remove-WSLDistribution {
    param([string]$DistributionName)
    
    Write-Info "Checking for existing WSL distributions..."
    
    $distributions = Get-WSLDistributions
    $found = $false
    
    foreach ($line in $distributions) {
        # Use .NET String.Contains with culture-invariant comparison
        if ($line.Contains($DistributionName, [System.StringComparison]::InvariantCultureIgnoreCase)) {
            $found = $true
            break
        }
    }
    
    if ($found) {
        Write-Warning "Found existing $DistributionName distribution. Unregistering..."
        
        try {
            wsl --unregister $DistributionName
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Successfully unregistered $DistributionName"
            } else {
                Write-ErrorMessage "Failed to unregister $DistributionName"
                return $false
            }
        }
        catch {
            Write-ErrorMessage "Error unregistering ${DistributionName}: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-Info "No existing $DistributionName distribution found"
    }
    
    return $true
}

# Function to enable WSL features
function Enable-WSLFeatures {
    Write-Info "Enabling WSL features..."
    
    try {
        # Enable WSL feature
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
        if ($wslFeature.State -ne "Enabled") {
            Write-Info "Enabling Windows Subsystem for Linux..."
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart
        }
        
        # Enable Virtual Machine Platform
        $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
        if ($vmFeature.State -ne "Enabled") {
            Write-Info "Enabling Virtual Machine Platform..."
            Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
        }
        
        Write-Success "WSL features enabled"
        return $true
    }
    catch {
        Write-ErrorMessage "Failed to enable WSL features: $($_.Exception.Message)"
        return $false
    }
}

# Function to install WSL
function Install-WSL {
    Write-Info "Installing WSL and $Distribution..."
    
    try {
        # Install WSL with specific distribution
        wsl --install --distribution $Distribution --no-launch
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "WSL and $Distribution installed successfully"
            return $true
        } else {
            Write-ErrorMessage "Failed to install WSL and $Distribution"
            return $false
        }
    }
    catch {
        Write-ErrorMessage "Error installing WSL: $($_.Exception.Message)"
        return $false
    }
}

# Function to set WSL version
function Set-WSLVersion {
    Write-Info "Setting WSL version to 2..."
    
    try {
        wsl --set-default-version 2
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "WSL default version set to 2"
            return $true
        } else {
            Write-Warning "Failed to set WSL default version"
            return $false
        }
    }
    catch {
        Write-ErrorMessage "Error setting WSL version: $($_.Exception.Message)"
        return $false
    }
}

# Function to wait for WSL to be ready
function Wait-ForWSL {
    param([int]$TimeoutSeconds = 60)
    
    Write-Info "Waiting for WSL to be ready..."
    
    $timeout = (Get-Date).AddSeconds($TimeoutSeconds)
    
    while ((Get-Date) -lt $timeout) {
        try {
            $result = wsl --distribution $Distribution --user root -- echo "WSL Ready" 2>$null
            if ($LASTEXITCODE -eq 0 -and $result -eq "WSL Ready") {
                Write-Success "WSL is ready"
                return $true
            }
        }
        catch {
            # WSL not ready yet
        }
        
        Start-Sleep -Seconds 2
    }
    
    Write-ErrorMessage "Timeout waiting for WSL to be ready"
    return $false
}

# Function to validate username
function Test-ValidUsername {
    param([string]$Username)
    
    if ([string]::IsNullOrWhiteSpace($Username)) {
        return $false
    }
    
    # Check for invalid characters (spaces, special chars that are problematic in Linux usernames)
    if ($Username -match '[^a-zA-Z0-9_-]') {
        return $false
    }
    
    # Check length (Linux usernames should be 32 chars or less)
    if ($Username.Length -gt 32) {
        return $false
    }
    
    # Username should not start with a number or hyphen
    if ($Username -match '^[0-9-]') {
        return $false
    }
    
    return $true
}

# Function to get user credentials
function Get-WSLUserCredentials {
    param([bool]$UseDefaults = $false)
    
    # Get current Windows username as default
    $defaultUsername = $env:USERNAME.ToLower()
    
    if ($UseDefaults) {
        # Use defaults when Force parameter is specified
        $username = $defaultUsername
        
        # Check for environment variable first, then use default
        $password = if ($env:WSL_DEFAULT_PASSWORD) { $env:WSL_DEFAULT_PASSWORD } else { "b" }
        
        Write-Info "Using default credentials (Force mode):"
        Write-Info "Username: $username"
        Write-Info "Password: [hidden]"
        
        return @{
            Username = $username
            Password = $password
        }
    } else {
        # Prompt for username with validation
        do {
            $username = Read-Host "Enter username for WSL (default: $defaultUsername)"
            if ([string]::IsNullOrWhiteSpace($username)) {
                $username = $defaultUsername
            }
            
            if (-not (Test-ValidUsername -Username $username)) {
                Write-Warning "Invalid username. Username must:"
                Write-Warning "- Not be empty"
                Write-Warning "- Only contain letters, numbers, underscores, and hyphens"
                Write-Warning "- Not start with a number or hyphen"
                Write-Warning "- Be 32 characters or less"
                $username = $null
            }
        } while (-not $username)
        
        # Prompt for password
        $securePassword = Read-Host "Enter password for user '$username'" -AsSecureString
        $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
        
        return @{
            Username = $username
            Password = $password
        }
    }
}

# Function to create WSL user
function New-WSLUser {
    param(
        [string]$Username,
        [string]$Password
    )
    
    Write-Info "Creating user '$Username' in WSL distribution '$Distribution'..."
    
    try {
        # Create the user with home directory, UID 1000, and default group
        # Use system default shell (zsh) by not specifying -s parameter
        Write-Info "Creating user '$Username' with UID 1000 and default shell..."
        $createUserResult = wsl --distribution $Distribution --user root -- sudo useradd -m -u 1000 "$Username" 2>&1
        if ($LASTEXITCODE -ne 0) {
            # Check if user already exists
            $userExists = wsl --distribution $Distribution -u root -- id "$Username" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Warning "User '$Username' already exists, skipping creation"
                # Check if existing user has correct UID
                $userInfo = wsl --distribution $Distribution --user root -- id -u "$Username" 2>$null
                if ($LASTEXITCODE -eq 0 -and $userInfo -eq "1000") {
                    Write-Info "Existing user '$Username' already has UID 1000"
                } else {
                    Write-Warning "Existing user '$Username' does not have UID 1000 (current UID: $userInfo)"
                }
            } else {
                Write-ErrorMessage "Failed to create user '$Username': $createUserResult"
                return $false
            }
        } else {
            Write-Success "User '$Username' created successfully with UID 1000"
            
            # Verify the shell was set correctly
            $userShell = wsl --distribution $Distribution --user root -- getent passwd "$Username" 2>$null | ForEach-Object { $_.Split(':')[6] }
            if ($userShell) {
                Write-Info "User shell set to: $userShell"
            }
        }
        
        # Set password for the user
        Write-Info "Setting password for user '$Username'..."
        $passwordCommand = "echo '${Username}:${Password}' | sudo chpasswd"
        $setPasswordResult = wsl --distribution $Distribution --user root -- bash -c $passwordCommand 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMessage "Failed to set password for user '$Username': $setPasswordResult"
            return $false
        } else {
            Write-Success "Password set for user '$Username'"
        }
        
        # Add user to sudo group
        Write-Info "Adding user '$Username' to sudo group..."
        $addSudoResult = wsl --distribution $Distribution --user root -- sudo usermod -aG sudo "$Username" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMessage "Failed to add user '$Username' to sudo group: $addSudoResult"
            return $false
        } else {
            Write-Success "User '$Username' added to sudo group"
        }
        
        # Ensure user has the correct shell (zsh)
        Write-Info "Verifying and setting shell to zsh for user '$Username'..."
        $currentShell = wsl --distribution $Distribution --user root -- getent passwd "$Username" 2>$null | ForEach-Object { $_.Split(':')[6] }
        if ($currentShell -ne "/usr/bin/zsh") {
            Write-Info "Current shell is '$currentShell', changing to zsh..."
            $setShellResult = wsl --distribution $Distribution --user root -- sudo chsh -s /usr/bin/zsh "$Username" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to set shell to zsh for user '$Username': $setShellResult"
                Write-Info "User can manually change shell later with: chsh -s /usr/bin/zsh"
            } else {
                Write-Success "Shell set to zsh for user '$Username'"
            }
        } else {
            Write-Success "User '$Username' already has zsh as default shell"
        }
        
        return $true
    }
    catch {
        Write-ErrorMessage "Error creating WSL user: $($_.Exception.Message)"
        return $false
    }
}

# Function to set default WSL user
function Set-WSLDefaultUser {
    param([string]$Username)
    
    Write-Info "Setting '$Username' as default user for distribution '$Distribution'..."
    
    try {
        # Set default user using wsl command
        # Create a multi-line bash script for better readability
        $bashScript = @"
# Check if [user] section exists, if not add it
if ! grep -q '^\[user\]' /etc/wsl.conf 2>/dev/null; then
    echo '[user]' >> /etc/wsl.conf
fi

# Check if default= line exists and update it, otherwise add it
if grep -q '^default=' /etc/wsl.conf 2>/dev/null; then
    sed -i 's/^default=.*/default=$Username/' /etc/wsl.conf
else
    echo 'default=$Username' >> /etc/wsl.conf
fi
"@

        $setDefaultResult = wsl --distribution $Distribution --user root -- bash -c $bashScript 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMessage "Failed to configure /etc/wsl.conf: $setDefaultResult"
            return $false
        } else {
            Write-Success "Default user configuration added to /etc/wsl.conf"
        }
        
        # Also set using wsl --user command for immediate effect
        Write-Info "Setting default user for immediate effect..."
        wsl --distribution $Distribution --user "$Username" -- echo "Default user set: $Username" 2>&1
        wsl --manage $Distribution --set-default-user $Username 2>$null | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Default user '$Username' verified"
        } else {
            Write-Warning "Could not verify default user immediately, but /etc/wsl.conf is configured"
        }
        
        return $true
    }
    catch {
        Write-ErrorMessage "Error setting default WSL user: $($_.Exception.Message)"
        return $false
    }
}

# Function to run installation script
function Start-WSLInstallation {
    Write-Info "Preparing installation..."
    
    # Check if installation script exists
    $installScript = Join-Path $InstallPath "install.sh"
    if (-not (Test-Path $installScript)) {
        Write-ErrorMessage "Installation script not found: $installScript"
        return $false
    }
    
    try {
        # Generate unique run ID for this execution
        $runId = Get-Date -Format "yyyyMMdd_HHmmss"
        Write-Info "Run ID: $runId"
        
        # Terminate WSL distribution to ensure clean state
        Write-Info "Ensuring WSL distribution is in clean state..."
        try {
            $terminateResult = wsl --terminate $Distribution 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "WSL distribution terminated successfully"
            } else {
                Write-Warning "WSL distribution termination returned non-zero exit code: $LASTEXITCODE"
                Write-Info "This may be normal if the distribution was not running"
            }
        }
        catch {
            Write-Warning "Error terminating WSL distribution: $($_.Exception.Message)"
            Write-Info "Continuing with installation (distribution may not have been running)"
        }
        
        # Give WSL a moment to fully terminate
        Start-Sleep -Seconds 2
        
        # Convert Windows path to WSL path for source
        $wslSourcePath = $InstallPath -replace "C:", "/mnt/c" -replace "\\", "/"
        
        # Expected log file path (still in Windows for monitoring)
        $expectedLogFile = Join-Path $InstallPath "logs\wsl-installation-$runId.log"
        Write-Info "Expected log file: $expectedLogFile"
        
        # Create logs directory if it doesn't exist
        $logsDir = Join-Path $InstallPath "logs"
        if (-not (Test-Path $logsDir)) {
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        }
        
        # Convert Windows log path to WSL path for the job
        $wslLogPath = $logsDir -replace "C:", "/mnt/c" -replace "\\", "/"
        
        if ($RunDirect) {
            Write-Info "Running installation directly from mounted script..."
            Write-Info "Mode: Direct execution (no temp copy)"
            Write-Info "Source: $wslSourcePath"
            
            # Start installation script in background and monitor progress
            Write-Info "Starting installation... (this may take several minutes)"
            Write-Info "Progress updates will be shown below:"
            Write-Info "─" * 60
            
            # Start the installation script as a background job with the run ID
            $jobScriptBlock = {
                param($Distribution, $SourcePath, $RunId, $LogPath, $ConfigSections)
                
                # Set environment variables for the installation script
                $envVars = @(
                    "WSL_INSTALL_RUN_ID=$RunId"
                    "LOG_DIR=$LogPath"
                )
                
                # Build the command with optional config sections
                $configArgs = ""
                if ($ConfigSections -and $ConfigSections.Count -gt 0) {
                    $configArgs = "--sections " + ($ConfigSections -join ",")
                }
                
                # Build environment variable string for env command
                $envString = $envVars -join " "
                
                # Build the full command more safely
                if ($configArgs) {
                    $installCommand = "cd '$SourcePath' && env $envString '$SourcePath/install.sh' $configArgs"
                } else {
                    $installCommand = "cd '$SourcePath' && env $envString '$SourcePath/install.sh'"
                }
                
                # Execute the installation script directly from mounted location
                try {
                    wsl --distribution $Distribution --user root -- bash -c $installCommand
                } catch {
                    Write-Host "Error executing WSL command: $($_.Exception.Message)" -ForegroundColor Red
                    throw
                }
            }
            
            $job = Start-Job -ScriptBlock $jobScriptBlock -ArgumentList $Distribution, $wslSourcePath, $runId, $wslLogPath, $Config
        }
        else {
            Write-Info "Using temp directory for installation (default mode)..."
            Write-Info "Mode: Copy to temp for better performance"
            
            # Define temp directory path in WSL
            $wslTempDir = "/tmp/wsl-install-$runId"
            
            Write-Info "Copying installation files to WSL temp directory for better performance..."
            Write-Info "Source: $wslSourcePath"
            Write-Info "Destination: $wslTempDir"
            
            # Use dedicated copy script for better maintainability
            $copyScriptPath = "$wslSourcePath/utils/copy-to-temp.sh"
            Write-Info "Using copy script: $copyScriptPath"
            
            # Run the copy script
            $copyResult = wsl --distribution $Distribution --user root -- bash "$copyScriptPath" "$wslSourcePath" "$wslTempDir"
            
            if ($LASTEXITCODE -ne 0) {
                Write-ErrorMessage "Failed to copy files to WSL temp directory"
                Write-ErrorMessage "Copy script exit code: $LASTEXITCODE"
                return $false
            }
            
            Write-Success "Files successfully copied to WSL temp directory"
            
            # Start installation script in background and monitor progress
            Write-Info "Starting installation... (this may take several minutes)"
            Write-Info "Progress updates will be shown below:"
            Write-Info "─" * 60
            
            # Start the installation script as a background job with the run ID
            $jobScriptBlock = {
                param($Distribution, $TempScript, $RunId, $LogPath, $SourcePath, $ConfigSections)
                
                # Use dedicated installation script for better maintainability
                $runInstallScript = "$SourcePath/utils/run-installation.sh"
                
                # Build the command with optional config sections
                $configArgs = ""
                if ($ConfigSections -and $ConfigSections.Count -gt 0) {
                    $configArgs = "--sections " + ($ConfigSections -join ",")
                }
                
                # Build the full command more safely
                if ($configArgs) {
                    wsl --distribution $Distribution --user root -- bash "$runInstallScript" "$TempScript" "$RunId" "$LogPath" "$configArgs"
                } else {
                    wsl --distribution $Distribution --user root -- bash "$runInstallScript" "$TempScript" "$RunId" "$LogPath"
                }
            }
            
            $job = Start-Job -ScriptBlock $jobScriptBlock -ArgumentList $Distribution, $wslTempDir, $runId, $wslLogPath, $wslSourcePath, @($Config)
        }
        
        # Monitor the specific log file for this run
        $lastLogSize = 0
        $lastLineCount = 0
        $progressPatterns = @(
            "Starting WSL Installation Script",
            "Installing Prerequisites", 
            "Installing APT Packages",
            "Installing Custom Software",
            "Installing Python Packages", 
            "Installing PowerShell Modules",
            "Running Configurations",
            "Installation Summary",
            "Installation script completed"
        )
        
        # Show spinner and monitor progress
        $spinnerChars = @('|', '/', '-', '\')
        $spinnerIndex = 0
        $lastProgressUpdate = Get-Date
        $installationStartTime = Get-Date
        $completedPhases = 0
        $totalPhases = 9  # Approximate number of major phases
        
        # Wait for log file to be created (with timeout)
        $logWaitTimeout = (Get-Date).AddSeconds(30)
        while (-not (Test-Path $expectedLogFile) -and (Get-Date) -lt $logWaitTimeout -and $job.State -eq "Running") {
            Write-Host "`r$($spinnerChars[$spinnerIndex % 4]) Waiting for installation to start..." -NoNewline -ForegroundColor Yellow
            $spinnerIndex++
            Start-Sleep -Milliseconds 200  # Faster spinner during wait
        }
        
        if (-not (Test-Path $expectedLogFile) -and $job.State -eq "Running") {
            [Console]::Write($script:ClearSpinnerLine)  # Clear spinner line and return cursor
            Write-Warning "Log file not created yet, continuing to monitor job..."
        }
        
        while ($job.State -eq "Running") {
            # Update spinner more frequently for better visual feedback
            $elapsed = (Get-Date) - $installationStartTime
            $elapsedStr = "{0:mm\:ss}" -f $elapsed
            Write-Host "`r$($spinnerChars[$spinnerIndex % 4]) Installing... (Elapsed: $elapsedStr)" -NoNewline -ForegroundColor Yellow
            $spinnerIndex++
            
            # Check for log file content if it exists (with delay to avoid race conditions)
            $hasNewContent = $false
            if (Test-Path $expectedLogFile) {
                Start-Sleep -Milliseconds 50  # Smaller delay to avoid reading while file is being written
                $content = Get-Content $expectedLogFile -ErrorAction SilentlyContinue
                if ($content) {
                    $currentLineCount = $content.Count
                    
                    # Process any new lines since last check (no filtering, just show new content)
                    if ($currentLineCount -gt $lastLineCount) {
                        $hasNewContent = $true
                        # Clear spinner line before showing new content
                        [Console]::Write($script:ClearSpinnerLine)
                        
                        $newLines = $content | Select-Object -Skip $lastLineCount
                        
                        foreach ($line in $newLines) {
                            # Check for major progress markers first
                            foreach ($pattern in $progressPatterns) {
                                if ($line -match $pattern) {
                                    $completedPhases++
                                    $progressPercent = [math]::Min(100, [math]::Round(($completedPhases / $totalPhases) * 100))
                                    Write-Success "✓ [$progressPercent%] $pattern"
                                    $lastProgressUpdate = Get-Date
                                    break
                                }
                            }
                            
                            # Show ALL other log lines (formatted) - no filtering, just proper display
                            if ($line -match "\[(INFO|SUCCESS|ERROR|WARN)\](.*)") {
                                $logLevel = $matches[1]
                                $message = $matches[2].Trim()
                                
                                if ($message.Length -gt 0) {
                                    switch ($logLevel) {
                                        "SUCCESS" { Write-Host "  ✓ $message" -ForegroundColor Green }
                                        "ERROR"   { Write-Host "  ✗ $message" -ForegroundColor Red }
                                        "WARN"    { Write-Host "  ⚠ $message" -ForegroundColor Yellow }
                                        "INFO"    { Write-Host "  → $message" -ForegroundColor Cyan }
                                    }
                                }
                            }
                        }
                        
                        $lastLineCount = $currentLineCount
                    }
                }
            }
            
            # Show time elapsed periodically
            $elapsed = (Get-Date) - $lastProgressUpdate
            if ($elapsed.TotalMinutes -gt 2) {
                # Clear spinner line before showing elapsed time message
                [Console]::Write($script:ClearSpinnerLine)
                $totalElapsed = (Get-Date) - $installationStartTime
                Write-Host "  ⏱ Still processing... ($([math]::Round($totalElapsed.TotalMinutes, 1)) min total elapsed)" -ForegroundColor Yellow
                $lastProgressUpdate = Get-Date
                $hasNewContent = $true  # Mark that we displayed content
            }
            
            # Sleep based on whether we had new content or not
            if ($hasNewContent) {
                Start-Sleep -Milliseconds 100  # Short sleep after displaying content
            } else {
                Start-Sleep -Milliseconds 150  # Faster spinner updates when no new content
            }
        }
        
        # Clear the spinner line
        [Console]::Write($script:ClearSpinnerLine)  # Clear spinner line and return cursor
        
        # Process any remaining log content after job completion
        Write-Info "Processing final log content..."
        Start-Sleep -Seconds 1  # Give time for final log writes to complete
        
        if (Test-Path $expectedLogFile) {
            $finalContent = Get-Content $expectedLogFile -ErrorAction SilentlyContinue
            if ($finalContent -and $finalContent.Count -gt $lastLineCount) {
                $finalNewLines = $finalContent | Select-Object -Skip $lastLineCount
                
                # Show any remaining lines that weren't displayed during real-time monitoring
                foreach ($line in $finalNewLines) {
                    if ($line -match "\[(INFO|SUCCESS|ERROR|WARN)\](.*)") {
                        $logLevel = $matches[1]
                        $message = $matches[2].Trim()
                        
                        if ($message.Length -gt 0) {
                            switch ($logLevel) {
                                "SUCCESS" { Write-Host "  ✓ $message" -ForegroundColor Green }
                                "ERROR"   { Write-Host "  ✗ $message" -ForegroundColor Red }
                                "WARN"    { Write-Host "  ⚠ $message" -ForegroundColor Yellow }
                                "INFO"    { Write-Host "  → $message" -ForegroundColor Cyan }
                            }
                        }
                    }
                }
            }
        }
        
        # Wait for job completion and get results
        $jobResult = Receive-Job -Job $job -Wait
        $jobExitCode = $job.State
        Remove-Job -Job $job
        
        Write-Info "─" * 60
        
        # Check the actual exit code from the bash script
        # The job state might be "Completed" even if the script failed
        if (Test-Path $expectedLogFile) {
            $logContent = Get-Content $expectedLogFile -Raw -ErrorAction SilentlyContinue
            $hasCompletionMessage = $logContent -match "Installation script completed!"
            
            # Check for failures - look for "Failed installations: X" where X > 0
            $failureCount = 0
            if ($logContent -match "Failed installations: (\d+)") {
                $failureCount = [int]$matches[1]
            }
            
            if ($hasCompletionMessage -and $failureCount -eq 0) {
                Write-Success "Installation script completed successfully"
                
                # Terminate WSL distribution to ensure configuration changes take effect
                Write-Info "Terminating WSL distribution to apply configuration changes..."
                try {
                    $terminateResult = wsl --terminate $Distribution 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "WSL distribution terminated successfully"
                        Write-Info "Configuration changes will be applied on next startup"
                    } else {
                        Write-Warning "WSL distribution termination returned non-zero exit code: $LASTEXITCODE"
                    }
                }
                catch {
                    Write-Warning "Error terminating WSL distribution: $($_.Exception.Message)"
                }
                
                return $true
            } elseif ($hasCompletionMessage -and $failureCount -gt 0) {
                Write-ErrorMessage "Installation script completed with $failureCount failures (check log for details)"
                return $false
            } else {
                Write-ErrorMessage "Installation script may not have completed properly"
                return $false
            }
        } else {
            Write-ErrorMessage "Could not find log file to verify installation results"
            return $false
        }
    }
    catch {
        # Check if the exception message contains curl progress output (which is not actually an error)
        $exceptionMessage = $_.Exception.Message
        if ($exceptionMessage -match "% Total.*% Received.*% Xferd.*Average Speed.*Time.*Time.*Time.*Current") {
            # This is just curl progress output, not a real error
            # Check the log file to determine actual success/failure
            if (Test-Path $expectedLogFile) {
                $logContent = Get-Content $expectedLogFile -Raw -ErrorAction SilentlyContinue
                $hasCompletionMessage = $logContent -match "Installation script completed!"
                
                # Check for failures - look for "Failed installations: X" where X > 0
                $failureCount = 0
                if ($logContent -match "Failed installations: (\d+)") {
                    $failureCount = [int]$matches[1]
                }
                
                if ($hasCompletionMessage -and $failureCount -eq 0) {
                    Write-Success "Installation script completed successfully"
                    
                    # Terminate WSL distribution to ensure configuration changes take effect
                    Write-Info "Terminating WSL distribution to apply configuration changes..."
                    try {
                        $terminateResult = wsl --terminate $Distribution 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "WSL distribution terminated successfully"
                            Write-Info "Configuration changes will be applied on next startup"
                        } else {
                            Write-Warning "WSL distribution termination returned non-zero exit code: $LASTEXITCODE"
                        }
                    }
                    catch {
                        Write-Warning "Error terminating WSL distribution: $($_.Exception.Message)"
                    }
                    
                    return $true
                } elseif ($hasCompletionMessage -and $failureCount -gt 0) {
                    Write-ErrorMessage "Installation script completed with $failureCount failures (check log for details)"
                    return $false
                } else {
                    Write-ErrorMessage "Installation script may not have completed properly"
                    return $false
                }
            } else {
                Write-ErrorMessage "Could not find log file to verify installation results"
                return $false
            }
        } else {
                Write-ErrorMessage "Error running installation script: $exceptionMessage"
                return $false
        }
    }
}

# Function to show completion message
function Show-CompletionMessage {
    param(
        [bool]$WasReset = $false,
        [string]$Username = $null
    )
    
    if ($WasReset) {
        Write-Success "WSL reset and installation completed!"
    } else {
        Write-Success "WSL installation script execution completed!"
    }
    Write-Info ""
    if ($Username) {
        Write-Info "Default user '$Username' has been created with sudo privileges"
        Write-Info ""
    }
    Write-Info "Next steps:"
    Write-Info "1. Start WSL: wsl --distribution $Distribution"
    Write-Info "2. Your development environment is ready to use"
    Write-Info "   Note: The distribution was terminated to apply configuration changes"
    Write-Info "3. Shell configuration (zsh, oh-my-zsh) will be active on first login"
    Write-Info "4. Run 'exec zsh' if zsh is not your default shell"
    Write-Info ""
    Write-Info "Useful commands:"
    Write-Info "- Test installation: wsl --distribution $Distribution --user root -- '$($InstallPath -replace '\\', '/' -replace 'C:', '/mnt/c')/test-installation.sh'"
    Write-Info "- View logs: Get-Content '$InstallPath\logs\*'"
    Write-Info "- Manual install: wsl --distribution $Distribution --user root -- '$($InstallPath -replace '\\', '/' -replace 'C:', '/mnt/c')/install.sh'"
    Write-Info "- Use -RunDirect for direct execution (slower but no temp copy): .\install-wsl.ps1 -AutoInstall -RunDirect"
    Write-Info ""
}

# Main script execution
function Main {
    Write-Info "WSL Installation and Management Script"
    Write-Info "======================================"
    Write-Info ""
    
    # Check admin privileges
    if (-not (Test-AdminPrivileges)) {
        Write-ErrorMessage "This script requires administrator privileges"
        Write-Info "Please run PowerShell as Administrator and try again"
        exit 1
    }
    
    # Confirm action unless Force is specified (only for WSL reset)
    if ($ResetWSL -and -not $Force) {
        Write-Warning "This will completely remove and reinstall WSL with $Distribution"
        Write-Warning "All data in the current WSL distribution will be lost!"
        Write-Info ""
        $confirmation = Read-Host "Are you sure you want to continue? (y/N)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-Info "Operation cancelled"
            exit 0
        }
        Write-Info ""
    }
    
    # Check WSL status
    $wslStatus = Get-WSLStatus
    Write-Info "Current WSL status: $(if ($wslStatus.Installed) { 'Installed' } else { 'Not installed' })"
    
    # Only perform WSL reset operations if ResetWSL is specified
    if ($ResetWSL) {
        Write-Info "ResetWSL parameter specified - performing WSL reset operations..."
        
        # Remove existing distribution
        if (-not (Remove-WSLDistribution -DistributionName $Distribution)) {
            Write-ErrorMessage "Failed to remove existing distribution"
            exit 1
        }
        
        # Enable WSL features
        if (-not (Enable-WSLFeatures)) {
            Write-ErrorMessage "Failed to enable WSL features"
            exit 1
        }
        
        # Install WSL
        if (-not (Install-WSL)) {
            Write-ErrorMessage "Failed to install WSL"
            exit 1
        }
        
        # Set WSL version
        Set-WSLVersion | Out-Null
        
        # Wait for WSL to be ready
        if (-not (Wait-ForWSL)) {
            Write-ErrorMessage "WSL is not ready"
            exit 1
        }
    } else {
        Write-Info "ResetWSL parameter not specified - skipping WSL reset operations"
        Write-Info "Using existing WSL installation"
        
        # Just verify WSL is available for installation script
        if (-not $wslStatus.Installed) {
            Write-ErrorMessage "WSL is not installed. Use -ResetWSL to install WSL first."
            exit 1
        }
        
        # Verify the specific distribution exists
        $distributions = Get-WSLDistributions
        $distributionFound = $false
        foreach ($line in $distributions) {
            if ($line.Contains($Distribution, [System.StringComparison]::InvariantCultureIgnoreCase)) {
                $distributionFound = $true
                break
            }
        }
        
        if (-not $distributionFound) {
            Write-ErrorMessage "Distribution '$Distribution' not found. Use -ResetWSL to install it."
            exit 1
        }
    }
    
    # Run installation script if AutoInstall is specified
    if ($AutoInstall) {
        # Run the installation script
        if (-not (Start-WSLInstallation)) {
            Write-ErrorMessage "Installation script failed"
            exit 1
        }
        
        # Get user credentials for WSL user creation
        Write-Info "Configuring WSL user account..."
        $userCredentials = Get-WSLUserCredentials -UseDefaults:$Force
        
        # Create the WSL user
        if (-not (New-WSLUser -Username $userCredentials.Username -Password $userCredentials.Password)) {
            Write-ErrorMessage "Failed to create WSL user"
            exit 1
        }
        
        # Set as default user
        if (-not (Set-WSLDefaultUser -Username $userCredentials.Username)) {
            Write-ErrorMessage "Failed to set default WSL user"
            exit 1
        }

        # Show completion message with username
        Show-CompletionMessage -WasReset:$ResetWSL -Username $userCredentials.Username
    } else {
        if ($ResetWSL) {
            Write-Info "WSL reset completed. Use -AutoInstall to run the installation script automatically."
        } else {
            Write-Info "Using existing WSL installation. Use -AutoInstall to run the installation script automatically."
        }
        Write-Info "Or manually run: wsl --distribution $Distribution --user root -- '$($InstallPath -replace '\\', '/' -replace 'C:', '/mnt/c')/install.sh'"
        Write-Info "Use -RunDirect to run directly from mounted script (no temp copy): .\install-wsl.ps1 -AutoInstall -RunDirect"
        
        # Show completion message without username
        Show-CompletionMessage -WasReset:$ResetWSL
    }
}

# Run main function
try {
    Main
}
catch {
    Write-ErrorMessage "Unexpected error: $($_.Exception.Message)"
    exit 1
}
