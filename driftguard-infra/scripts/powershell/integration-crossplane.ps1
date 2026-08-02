param(
  [string]$Context = 'driftguard-dev',
  [string]$Namespace = 'crossplane-system',
  [string]$ClaimName = 'driftguard-sample-bucket',
  [int]$TimeoutSeconds = 900,
  [switch]$ConfirmDeprovision
)

$ErrorActionPreference = 'Stop'
if (-not $ConfirmDeprovision) {
  throw 'This integration test deletes the sample AWS resource. Re-run with -ConfirmDeprovision against a dedicated test account.'
}
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { throw 'kubectl is required.' }

function Invoke-Checked([string[]]$Arguments) {
  & kubectl @Arguments
  if ($LASTEXITCODE -ne 0) { throw "kubectl failed with exit code ${LASTEXITCODE}" }
}

function Invoke-Captured([string[]]$Arguments) {
  $output = & kubectl @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "kubectl failed with exit code ${LASTEXITCODE}: $($output -join ' ')" }
  return ($output -join "`n")
}

$providerTimeout = [Math]::Min($TimeoutSeconds, 600)
Invoke-Checked @('--context', $Context, '-n', $Namespace, 'wait', '--for=condition=Healthy', 'provider.pkg.crossplane.io/provider-aws', "--timeout=${providerTimeout}s")
Invoke-Checked @('--context', $Context, '-n', $Namespace, 'wait', '--for=condition=Healthy', 'providerconfig.aws.upbound.io/default', "--timeout=${providerTimeout}s")
Invoke-Checked @('--context', $Context, '-n', $Namespace, 'wait', '--for=condition=Established', 'compositeresourcedefinition.apiextensions.crossplane.io/xbuckets.storage.driftguard.io', "--timeout=${providerTimeout}s")
Invoke-Checked @('--context', $Context, '-n', $Namespace, 'wait', '--for=condition=Ready', "bucket.storage.driftguard.io/${ClaimName}", "--timeout=${TimeoutSeconds}s")

$claim = Invoke-Captured @('--context', $Context, '-n', $Namespace, 'get', 'bucket.storage.driftguard.io', $ClaimName, '-o', 'json') | ConvertFrom-Json
$ready = @($claim.status.conditions | Where-Object { $_.type -eq 'Ready' -and $_.status -eq 'True' })
if ($ready.Count -ne 1) { throw "Crossplane claim ${ClaimName} did not report Ready=True." }

Invoke-Checked @('--context', $Context, '-n', $Namespace, 'delete', 'bucket.storage.driftguard.io', $ClaimName)
Invoke-Checked @('--context', $Context, '-n', $Namespace, 'wait', '--for=delete', "bucket.storage.driftguard.io/${ClaimName}", "--timeout=${TimeoutSeconds}s")
Write-Host "Crossplane claim ${ClaimName} became Ready and was deprovisioned within the configured timeout."
