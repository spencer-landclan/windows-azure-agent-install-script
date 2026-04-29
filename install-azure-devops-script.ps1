[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$AzureDevOpsUrl,

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$PoolName = 'Default',

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$AgentName = $env:COMPUTERNAME,

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$InstallDir = "C:\agent",

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$WorkDir = "_work",

  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [SecureString]$Pat,

  [Parameter()]
  [ValidateNotNullOrEmpty()]
  [string]$ServiceAccount = "NT AUTHORITY\SYSTEM",

  [Parameter()]
  [SecureString]$ServiceAccountPassword,

  [Parameter()]
  [switch]$ReplaceExisting
)

$ErrorActionPreference = "Stop"

function Assert-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]::new($identity)
  $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

  if (!$isAdmin) {
    throw "Run this script from an elevated PowerShell session."
  }
}

function Convert-SecureStringToPlainText {
  param(
    [Parameter(Mandatory = $true)]
    [SecureString]$SecureValue
  )

  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
  try {
    [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    if ($bstr -ne [IntPtr]::Zero) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
  }
}

function Get-AgentDownloadUrl {
  Write-Host "Finding latest Azure Pipelines Windows x64 agent release..."

  $release = Invoke-RestMethod `
    -Uri "https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest" `
    -Headers @{ "User-Agent" = "azure-devops-agent-bootstrap" } `
    -UseBasicParsing

  $asset = $release.assets |
    Where-Object { $_.name -match '^vsts-agent-win-x64-.+\.zip$' } |
    Select-Object -First 1

  if (!$asset) {
    throw "Could not find a Windows x64 Azure Pipelines agent asset in the latest release."
  }

  Write-Host "Using agent package $($asset.name)."
  $asset.browser_download_url
}

function Ensure-Tls12 {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

Assert-Administrator
Ensure-Tls12

$plainPat = Convert-SecureStringToPlainText -SecureValue $Pat
$plainServicePassword = $null
if ($ServiceAccountPassword) {
  $plainServicePassword = Convert-SecureStringToPlainText -SecureValue $ServiceAccountPassword
}

try {
  if (!(Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
  }

  $configCmd = Join-Path $InstallDir "config.cmd"
  $agentMarker = Join-Path $InstallDir ".agent"

  if ((Test-Path $agentMarker) -and !$ReplaceExisting) {
    Write-Host "Azure DevOps agent already appears configured in $InstallDir. Use -ReplaceExisting to reconfigure it."
    exit 0
  }

  if ((Test-Path $agentMarker) -and $ReplaceExisting) {
    Write-Host "Removing existing Azure DevOps agent configuration..."
    Push-Location $InstallDir
    try {
      & $configCmd remove --unattended --auth pat --token $plainPat
      if ($LASTEXITCODE -ne 0) {
        throw "Agent removal failed with exit code $LASTEXITCODE."
      }
    } finally {
      Pop-Location
    }
  }

  if (!(Test-Path $configCmd)) {
    $downloadUrl = Get-AgentDownloadUrl
    $zipPath = Join-Path $env:TEMP "azure-pipelines-agent.zip"

    Write-Host "Downloading Azure Pipelines agent..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

    Write-Host "Extracting agent to $InstallDir..."
    Expand-Archive -Path $zipPath -DestinationPath $InstallDir -Force
    Remove-Item -Path $zipPath -Force
  } else {
    Write-Host "Agent files already exist in $InstallDir. Skipping download."
  }

  $configArgs = @(
    "--unattended",
    "--url", $AzureDevOpsUrl,
    "--auth", "pat",
    "--token", $plainPat,
    "--pool", $PoolName,
    "--agent", $AgentName,
    "--work", $WorkDir,
    "--runAsService",
    "--windowsLogonAccount", $ServiceAccount,
    "--acceptTeeEula"
  )

  if ($plainServicePassword) {
    $configArgs += @("--windowsLogonPassword", $plainServicePassword)
  }

  Write-Host "Configuring Azure DevOps agent '$AgentName' in pool '$PoolName'..."
  Push-Location $InstallDir
  try {
    & ".\config.cmd" @configArgs
    if ($LASTEXITCODE -ne 0) {
      throw "Agent configuration failed with exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }

  Write-Host "Azure DevOps agent '$AgentName' installed and configured as a Windows service."
} finally {
  $plainPat = $null
  $plainServicePassword = $null
}
