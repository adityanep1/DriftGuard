param(
  [string]$Context = 'driftguard-dev',
  [string]$ConfigRepoRevision = 'main'
)

$ErrorActionPreference = 'Stop'
foreach ($command in 'kubectl', 'argocd') {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "$command is required for this integration test."
  }
}

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

Invoke-Checked kubectl @('--context', $Context, '-n', 'argocd', 'wait', '--for=condition=Established', 'crd/applications.argoproj.io', '--timeout=180s')
Invoke-Checked argocd @('app', 'wait', 'root-application', '--app-namespace', 'argocd', '--sync', '--health', '--revision', $ConfigRepoRevision, '--timeout', '180')

$expected = @(
  'argocd-projects',
  'driftguard-application-sets',
  'driftguard-observability-config',
  'driftguard-security-policies',
  'driftguard-external-secrets',
  'karpenter-nodepool',
  'falco',
  'falcosidekick'
)
foreach ($name in $expected) {
  Invoke-Checked argocd @('app', 'get', $name, '--app-namespace', 'argocd', '--hard-refresh', '--output', 'wide')
}

$generated = kubectl --context $Context -n argocd get applications -o json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Unable to read generated ArgoCD Applications.' }
$generatedNames = @($generated.items | ForEach-Object { $_.metadata.name })
$missing = @($expected | Where-Object { $_ -notin $generatedNames })
if ($missing.Count -gt 0) {
  throw "Root_Application did not discover all referenced children: $($missing -join ', ')"
}
Write-Host "ArgoCD root and $($generatedNames.Count) child Applications are synchronized and healthy."
