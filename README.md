# Azure DevOps Agent Installer

This repository contains a PowerShell script for installing a self-hosted Azure DevOps agent on a new Windows VM.

The script downloads the latest Windows x64 Azure Pipelines agent, extracts it locally, configures it against your Azure DevOps organization, and installs it as a Windows service.

## Files

- `install-azure-devops-script.ps1`: Installs and configures the Azure DevOps agent.
- `README.md`: Usage instructions for the installer repository.

## Requirements

- Windows VM.
- PowerShell running as Administrator.
- Network access to GitHub releases and Azure DevOps.
- An Azure DevOps personal access token with permission to register agents.

The PAT typically needs `Agent Pools` read and manage permission.

The Azure DevOps user that creates the PAT must also have permission to manage the target agent pool. PAT scopes do not override Azure DevOps pool permissions.

## Quick Start

Run PowerShell as Administrator on the VM.

Download and run the installer. Paste the whole block into PowerShell, then press Enter once at the end:

```powershell
& {
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

  $scriptPath = Join-Path $env:USERPROFILE "Downloads\install-azure-devops-script.ps1"
  $scriptUrl = "https://raw.githubusercontent.com/spencer-landclan/windows-azure-agent-install-script/main/install-azure-devops-script.ps1"

  Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath

  Unblock-File -Path $scriptPath

  $pat = Read-Host "Azure DevOps PAT" -AsSecureString

  & $scriptPath `
    -AzureDevOpsUrl "https://dev.azure.com/caddo-apps/" `
    -PoolName "Default" `
    -AgentName "$env:COMPUTERNAME" `
    -Pat $pat
}
```

The PAT is mandatory and is passed as a secure string.

## Defaults

By default, the script uses:

| Setting | Default |
| --- | --- |
| Agent pool | `Default` |
| Agent name | Current computer name |
| Install directory | `C:\agent` |
| Work directory | `_work` |
| Windows service account | Local System (`NT AUTHORITY\SYSTEM`) |

Local System does not require a service account password.

## Parameters

| Parameter | Required | Default | Purpose |
| --- | --- | --- | --- |
| `AzureDevOpsUrl` | Yes | None | Azure DevOps organization URL, such as `https://dev.azure.com/caddo-apps/`. |
| `PoolName` | No | `Default` | Azure DevOps agent pool to register the agent in. |
| `AgentName` | No | Current computer name | Agent name shown in Azure DevOps. |
| `InstallDir` | No | `C:\agent` | Directory where the agent files are installed. |
| `WorkDir` | No | `_work` | Agent work folder. |
| `Pat` | Yes | None | Azure DevOps PAT as a secure string. |
| `ServiceAccount` | No | `NT AUTHORITY\SYSTEM` | Windows account used by the agent service. |
| `ServiceAccountPassword` | No | None | Password for custom service accounts. Not needed for Local System. |
| `ReplaceExisting` | No | Off | Removes and reconfigures an existing agent in the same folder. |

## Examples

Install into the default pool with the VM name as the agent name:

```powershell
$pat = Read-Host "Azure DevOps PAT" -AsSecureString

& "$env:USERPROFILE\Downloads\install-azure-devops-script.ps1" `
  -AzureDevOpsUrl "https://dev.azure.com/caddo-apps/" `
  -Pat $pat
```

Install into a specific pool with a specific agent name:

```powershell
$pat = Read-Host "Azure DevOps PAT" -AsSecureString

& "$env:USERPROFILE\Downloads\install-azure-devops-script.ps1" `
  -AzureDevOpsUrl "https://dev.azure.com/caddo-apps/" `
  -PoolName "Default" `
  -AgentName "vm-web-01" `
  -Pat $pat
```

Reconfigure an existing agent:

```powershell
$pat = Read-Host "Azure DevOps PAT" -AsSecureString

& "$env:USERPROFILE\Downloads\install-azure-devops-script.ps1" `
  -AzureDevOpsUrl "https://dev.azure.com/caddo-apps/" `
  -PoolName "Default" `
  -AgentName "vm-web-01" `
  -Pat $pat `
  -ReplaceExisting
```

Use a custom service account:

```powershell
$pat = Read-Host "Azure DevOps PAT" -AsSecureString
$password = Read-Host "Service account password" -AsSecureString

& "$env:USERPROFILE\Downloads\install-azure-devops-script.ps1" `
  -AzureDevOpsUrl "https://dev.azure.com/caddo-apps/" `
  -PoolName "Default" `
  -AgentName "vm-web-01" `
  -Pat $pat `
  -ServiceAccount "DOMAIN\buildsvc" `
  -ServiceAccountPassword $password
```

## Notes

- Run the script from an elevated PowerShell session.
- The agent is installed as a Windows service and starts automatically after configuration.
- If an agent is already configured in the install directory, the script exits unless `-ReplaceExisting` is passed.
- The script download URL points at the `main` branch of this public GitHub repository:

```text
https://github.com/spencer-landclan/windows-azure-agent-install-script
```

## Troubleshooting

### VS30063: You are not authorized to access https://dev.azure.com

This error means the script downloaded successfully, but Azure DevOps rejected the PAT during agent registration.

Check these items:

- Create the PAT while signed in to `https://dev.azure.com/caddo-apps/`.
- When creating the PAT, select the `caddo-apps` organization or `All accessible organizations`.
- Select `Show all scopes`, then grant `Agent Pools` read and manage.
- Make sure the PAT is not expired.
- Make sure the user that created the PAT has permission to manage the target pool, such as `Default`.
- Use the organization URL with the org name: `https://dev.azure.com/caddo-apps/`.

After creating a new PAT, rerun the Quick Start block and paste the new token when prompted.

You can also test the PAT before running the installer:

```powershell
$orgUrl = "https://dev.azure.com/caddo-apps/"
$poolName = "Default"
$pat = Read-Host "Azure DevOps PAT" -AsSecureString

$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pat)
try {
  $plainPat = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr).Trim()
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

$encodedPool = [Uri]::EscapeDataString($poolName)
$apiUrl = "${orgUrl}_apis/distributedtask/pools?poolName=$encodedPool&api-version=7.1-preview.1"
$basicToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$plainPat"))

Invoke-RestMethod `
  -Uri $apiUrl `
  -Headers @{ Authorization = "Basic $basicToken" }
```

If this test returns `VS30063`, the issue is definitely the PAT, organization selection, or pool permissions.
