<#
  dev_setup_check.ps1
  Checks your Windows machine for every tool needed for the flight delay project,
  and optionally installs whatever is missing.

  Usage (from the folder containing this file):
    Check only:         powershell -ExecutionPolicy Bypass -File .\dev_setup_check.ps1
    Check and install:  powershell -ExecutionPolicy Bypass -File .\dev_setup_check.ps1 -Install
#>
param([switch]$Install)

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-WithWinget($id, $source) {
    Write-Host "  Installing $id ..." -ForegroundColor Cyan
    $wingetArgs = @("install", "--id", $id, "-e", "--accept-package-agreements", "--accept-source-agreements")
    if ($source) { $wingetArgs += @("--source", $source) }
    winget @wingetArgs
}

# ---------------------------------------------------------------------------
# 1. Command line tools
# ---------------------------------------------------------------------------
$cliTools = @(
    @{ Name = "winget";         Cmd = "winget";     VerArg = "--version"; Winget = "" },
    @{ Name = "Git";            Cmd = "git";        VerArg = "--version"; Winget = "Git.Git" },
    @{ Name = "VS Code";        Cmd = "code";       VerArg = "--version"; Winget = "Microsoft.VisualStudioCode" },
    @{ Name = "Docker";         Cmd = "docker";     VerArg = "--version"; Winget = "Docker.DockerDesktop" },
    @{ Name = "uv";             Cmd = "uv";         VerArg = "--version"; Winget = "astral-sh.uv" },
    @{ Name = "AWS CLI";        Cmd = "aws";        VerArg = "--version"; Winget = "Amazon.AWSCLI" },
    @{ Name = "Terraform";      Cmd = "terraform";  VerArg = "-version";  Winget = "Hashicorp.Terraform" },
    @{ Name = "Databricks CLI"; Cmd = "databricks"; VerArg = "--version"; Winget = "Databricks.DatabricksCLI" },
    @{ Name = "Snowflake CLI";  Cmd = "snow";       VerArg = "--version"; Winget = "" },   # installed with uv
    @{ Name = "GitHub CLI";     Cmd = "gh";         VerArg = "--version"; Winget = "GitHub.cli" },
    @{ Name = "tflint";         Cmd = "tflint";     VerArg = "--version"; Winget = "TerraformLinters.tflint" },
    @{ Name = "checkov";        Cmd = "checkov";    VerArg = "--version"; Winget = "" }
)

function Check-Cli {
    foreach ($t in $cliTools) {
        $c = Get-Command $t.Cmd -ErrorAction SilentlyContinue
        if ($c) {
            $v = (& $t.Cmd $t.VerArg 2>&1 | Select-Object -First 1)
            [PSCustomObject]@{ Tool = $t.Name; Status = "Installed"; Detail = "$v" }
        } else {
            [PSCustomObject]@{ Tool = $t.Name; Status = "MISSING"; Detail = "" }
        }
    }
}

# ---------------------------------------------------------------------------
# 2. Desktop applications
# ---------------------------------------------------------------------------
$desktopApps = @(
    @{ Name = "Power BI Desktop"; Reg = "*Power BI*";      Store = "*PowerBI*";         Winget = "9NTXR16HNW1T"; Source = "msstore" },
    @{ Name = "DBeaver";          Reg = "*DBeaver*";       Store = "";                  Winget = "DBeaver.DBeaver.Community"; Source = "" },
    @{ Name = "Windows Terminal"; Reg = "";                Store = "*WindowsTerminal*"; Winget = "Microsoft.WindowsTerminal"; Source = "" }
)

function Get-InstalledNames {
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    Get-ItemProperty $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } | ForEach-Object { $_.DisplayName }
}

function Get-StoreNames {
    try { Get-AppxPackage -ErrorAction Stop | ForEach-Object { $_.Name } }
    catch { @() }
}

function Check-Apps {
    $reg = Get-InstalledNames
    $store = Get-StoreNames
    foreach ($a in $desktopApps) {
        $found = $false
        if ($a.Reg   -and ($reg   | Where-Object { $_ -like $a.Reg }))   { $found = $true }
        if ($a.Store -and ($store | Where-Object { $_ -like $a.Store })) { $found = $true }
        [PSCustomObject]@{ Tool = $a.Name; Status = $(if ($found) { "Installed" } else { "MISSING" }); Detail = "" }
    }
}

# ---------------------------------------------------------------------------
# 3. WSL with Ubuntu
# ---------------------------------------------------------------------------
function Check-Wsl {
    $ok = $false
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        $out = (wsl -l -q 2>$null) -replace "`0", ""
        if ($out -match "Ubuntu") { $ok = $true }
    }
    [PSCustomObject]@{ Tool = "WSL2 + Ubuntu"; Status = $(if ($ok) { "Installed" } else { "MISSING" }); Detail = "" }
}

# ---------------------------------------------------------------------------
# 4. VS Code extensions
# ---------------------------------------------------------------------------
$extensions = @(
    "ms-python.python",
    "ms-toolsai.jupyter",
    "amazonwebservices.aws-toolkit-vscode",
    "hashicorp.terraform",
    "databricks.databricks",
    "snowflake.snowflake-vsc",
    "innoverio.vscode-dbt-power-user",
    "ms-azuretools.vscode-docker",
    "redhat.vscode-yaml",
    "eamodio.gitlens",
    "charliermarsh.ruff"
)

function Check-Extensions {
    if (-not (Get-Command code -ErrorAction SilentlyContinue)) { return @() }
    $have = (code --list-extensions) | ForEach-Object { $_.ToLower() }
    foreach ($e in $extensions) {
        [PSCustomObject]@{ Tool = "ext: $e"; Status = $(if ($have -contains $e.ToLower()) { "Installed" } else { "MISSING" }); Detail = "" }
    }
}

# ---------------------------------------------------------------------------
# Run checks
# ---------------------------------------------------------------------------
function Show-Report {
    $all = @()
    $all += Check-Wsl
    $all += Check-Cli
    $all += Check-Apps
    $all += Check-Extensions
    Write-Host ""
    Write-Host "=== Setup report ===" -ForegroundColor Yellow
    foreach ($r in $all) {
        $color = if ($r.Status -eq "Installed") { "Green" } else { "Red" }
        Write-Host ("{0,-45} {1,-10} {2}" -f $r.Tool, $r.Status, $r.Detail) -ForegroundColor $color
    }
    return $all
}

$report = Show-Report

if (-not $Install) {
    Write-Host ""
    Write-Host "Run again with -Install to install missing items." -ForegroundColor Yellow
    exit
}

# ---------------------------------------------------------------------------
# Install missing items
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Installing missing items ===" -ForegroundColor Yellow

foreach ($t in $cliTools) {
    if ($t.Winget -and -not (Get-Command $t.Cmd -ErrorAction SilentlyContinue)) {
        Install-WithWinget $t.Winget ""
    }
}
Refresh-Path

# Snowflake CLI through uv
if (-not (Get-Command snow -ErrorAction SilentlyContinue)) {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Host "  Installing Snowflake CLI with uv ..." -ForegroundColor Cyan
        uv tool install snowflake-cli
        Refresh-Path
    } else {
        Write-Host "  Skipping Snowflake CLI: uv not found yet. Restart the terminal and rerun." -ForegroundColor Red
    }
}

$appStatus = Check-Apps
foreach ($a in $desktopApps) {
    $s = $appStatus | Where-Object { $_.Tool -eq $a.Name }
    if ($s.Status -eq "MISSING" -and $a.Winget) {
        Install-WithWinget $a.Winget $a.Source
    }
}

if (Get-Command code -ErrorAction SilentlyContinue) {
    $have = (code --list-extensions) | ForEach-Object { $_.ToLower() }
    foreach ($e in $extensions) {
        if ($have -notcontains $e.ToLower()) {
            Write-Host "  Installing VS Code extension $e ..." -ForegroundColor Cyan
            code --install-extension $e
        }
    }
}

Write-Host ""
Write-Host "=== Manual steps still needed (if marked MISSING above) ===" -ForegroundColor Yellow
Write-Host "  WSL2 + Ubuntu : open PowerShell as Administrator, run  wsl --install -d Ubuntu  then restart"
Write-Host "  Tableau Public: download the desktop app from the Tableau Public website"
Write-Host "  Docker Desktop: open it once, accept terms, enable the WSL2 backend in Settings"
Write-Host ""
Write-Host "Close and reopen your terminal, then run this script again without -Install to confirm." -ForegroundColor Yellow

