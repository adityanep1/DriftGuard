param(
  [string]$Hostname = 'demo.example.invalid',
  [switch]$Confirm
)

$ErrorActionPreference = 'Stop'
if (-not $Confirm) {
  throw 'This smoke test provisions and destroys AWS resources. Re-run with -Confirm after reviewing the plan.'
}

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$live = Join-Path $root 'live/dev'
$context = 'driftguard-dev'
$namespace = 'demo-dev'
$app = 'demo-service-dev'

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
  Write-Host "> $Command $($Arguments -join ' ')"
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

try {
  Push-Location $live
  try {
    Invoke-Checked terraform @('init', '-input=false')
    Invoke-Checked terraform @('apply', '-input=false', '-auto-approve')
  } finally { Pop-Location }

  Invoke-Checked argocd @('app', 'wait', 'root-application', '--app-namespace', 'argocd', '--health', '--sync', '--timeout', '600')
  Invoke-Checked kubectl @('--context', $context, '-n', $namespace, 'wait', '--for=condition=Available', 'rollout/demo-service', '--timeout=300s')
  $health = Invoke-WebRequest -Uri "https://$Hostname/healthz" -UseBasicParsing
  if ($health.StatusCode -ne 200) { throw "HTTPS health check returned $($health.StatusCode)" }

  Write-Host 'Injecting replica drift; ArgoCD should report OutOfSync and self-heal.'
  Invoke-Checked kubectl @('--context', $context, '-n', $namespace, 'scale', 'rollout/demo-service', '--replicas=1')
  Invoke-Checked argocd @('app', 'wait', $app, '--app-namespace', 'argocd', '--sync', '--timeout', '180')
  Start-Sleep -Seconds 120
  Invoke-Checked kubectl @('--context', $context, '-n', $namespace, 'wait', '--for=jsonpath={.spec.replicas}=2', 'rollout/demo-service', '--timeout=120s')

  Write-Host 'Injecting a bad canary image; Argo Rollouts should abort and restore stable traffic.'
  Invoke-Checked kubectl @('--context', $context, '-n', $namespace, 'argo', 'rollouts', 'set', 'image', 'rollout/demo-service', 'demo-service=ghcr.io/your-org/demo-service:known-bad')
  Invoke-Checked kubectl @('--context', $context, '-n', $namespace, 'argo', 'rollouts', 'abort', 'demo-service')
  Invoke-Checked kubectl @('--context', $context, '-n', $namespace, 'argo', 'rollouts', 'get', 'rollout', 'demo-service', '--watch=false')
} finally {
  Write-Host 'Running single-command teardown for the ephemeral environment.'
  & $PSScriptRoot\teardown.ps1 -Environment dev -Confirm
}
