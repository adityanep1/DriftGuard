param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('dev', 'staging', 'prod')]
  [string]$Environment,
  [string]$Region = 'us-east-1',
  [switch]$Confirm
)

$ErrorActionPreference = 'Stop'
if (-not $Confirm) {
  throw 'Teardown is destructive. Re-run with -Confirm after reviewing the plan.'
}

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$live = Join-Path $root "live/$Environment"
$log = Join-Path $root "teardown-$Environment.log"

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
  & $Command @Arguments 2>&1 | Tee-Object -FilePath $log -Append
  if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

try {
  Write-Host "Removing ALB-backed ingress resources before Terraform destroy..."
  Invoke-Checked kubectl @('--context', "driftguard-$Environment", 'delete', 'ingress', '--all', '--all-namespaces', '--wait=true', '--timeout=300s')
  Push-Location $live
  try {
    Invoke-Checked terraform @('init', '-input=false')
    Invoke-Checked terraform @('destroy', '-input=false', '-auto-approve')
  } finally { Pop-Location }
  Write-Host "Teardown completed for $Environment."
} catch {
  Write-Error "Teardown incomplete for ${Environment}: $($_.Exception.Message)"
  Write-Error "Remaining resources were not modified after the failing operation. Re-run after remediation; see $log."
  exit 1
}
