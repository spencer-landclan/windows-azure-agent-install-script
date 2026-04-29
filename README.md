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
    -AzureDevOpsUrl "https://dev.azure.com/caddo-apps" `
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
| `AzureDevOpsUrl` | Yes | None | Azure DevOps organization URL, such as `https://dev.azure.com/caddo-apps`. |
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
  -AzureDevOpsUrl "https://dev.azure.com/caddo-apps" `
  -Pat $pat
```

Install into a specific pool with a specific agent name:

```powershell
$pat = Read-Host "Azure DevOps PAT" -AsSecureString

& "$env:USERPROFILE\Downloads\install-azure-devops-script.ps1" `
  -AzureDevOpsUrl "https://dev.azure.com/caddo-apps" `
  -PoolName "Default" `
  -AgentName "vm-web-01" `
  -Pat $pat
```

Reconfigure an existing agent:

```powershell
$pat = Read-Host "Azure DevOps PAT" -AsSecureString

& "$env:USERPROFILE\Downloads\install-azure-devops-script.ps1" `
  -AzureDevOpsUrl "https://dev.azure.com/caddo-apps" `
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
  -AzureDevOpsUrl "https://dev.azure.com/caddo-apps" `
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
