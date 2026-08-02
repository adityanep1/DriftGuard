param(
  [string]$Context = 'driftguard-dev',
  [switch]$RunMutationChecks
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { throw 'kubectl is required.' }

function Invoke-Checked([string]$Command, [string[]]$Arguments) {
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

function Invoke-Captured([string]$Command, [string[]]$Arguments) {
  $output = & $Command @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code ${LASTEXITCODE}: $($output -join ' ')" }
  return ($output -join "`n")
}

function Get-Json([string[]]$Arguments) {
  return (Invoke-Captured kubectl $Arguments | ConvertFrom-Json)
}

function Assert-PrivilegedAdmissionDenied {
  $arguments = @('--context', $Context, '-n', 'demo-dev', 'run', 'gatekeeper-negative-test', '--image=busybox:1.36', '--restart=Never', '--dry-run=server', '--overrides', '{"spec":{"containers":[{"name":"negative","image":"busybox:1.36","securityContext":{"privileged":true}}]}}')
  & kubectl @arguments 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { throw 'Gatekeeper admitted a privileged test pod.' }
}

$checks = @(
  @('external-secrets', 'deployment/external-secrets', 'deployment/external-secrets-webhook'),
  @('gatekeeper-system', 'deployment/gatekeeper-controller-manager'),
  @('falco', 'daemonset/falco')
)
foreach ($check in $checks) {
  $namespace = $check[0]
  foreach ($resource in $check[1..($check.Count - 1)]) {
    Invoke-Checked kubectl @('--context', $Context, '-n', $namespace, 'rollout', 'status', $resource, '--timeout=300s')
  }
}

if ($RunMutationChecks) {
  Write-Host 'Running ESO preservation, Gatekeeper fail-closed, and Falco alert-path checks in the supplied test cluster.'
  $gitopsRoot = Join-Path $PSScriptRoot '..\..\..\driftguard-gitops'
  Invoke-Checked kubectl @('--context', $Context, 'apply', '--server-side', '-f', (Join-Path $gitopsRoot 'policies\constraints\baseline.yaml'))

  # ESO must materialize the reference, then preserve the last materialized value when its store is broken.
  Invoke-Checked kubectl @('--context', $Context, '-n', 'demo-dev', 'wait', '--for=condition=Ready', 'externalsecret/demo-service-config', '--timeout=60s')
  $beforeSecret = Get-Json @('--context', $Context, '-n', 'demo-dev', 'get', 'secret', 'demo-service-config', '-o', 'json')
  if (-not $beforeSecret.data) { throw 'ESO created no materialized secret data.' }
  $beforeData = $beforeSecret.data | ConvertTo-Json -Compress
  $originalStore = Invoke-Captured kubectl @('--context', $Context, '-n', 'demo-dev', 'get', 'secretstore', 'aws-secrets-manager', '-o', 'yaml')
  $storeFile = Join-Path ([IO.Path]::GetTempPath()) ("driftguard-secretstore-{0}.yaml" -f [guid]::NewGuid())
  try {
    Invoke-Checked kubectl @('--context', $Context, '-n', 'demo-dev', 'patch', 'secretstore', 'aws-secrets-manager', '--type', 'merge', '-p', '{"spec":{"provider":{"aws":{"region":"invalid-driftguard-region"}}}}')
    Invoke-Checked kubectl @('--context', $Context, '-n', 'demo-dev', 'annotate', 'externalsecret', 'demo-service-config', "driftguard.io/force-sync=$([DateTime]::UtcNow.Ticks)", '--overwrite')
    Start-Sleep -Seconds 35
    $afterSecret = Get-Json @('--context', $Context, '-n', 'demo-dev', 'get', 'secret', 'demo-service-config', '-o', 'json')
    $afterData = $afterSecret.data | ConvertTo-Json -Compress
    if ($beforeData -ne $afterData) { throw 'ESO changed or removed previously materialized values after store failure.' }
  } finally {
    Set-Content -Path $storeFile -Value $originalStore -Encoding UTF8
    Invoke-Checked kubectl @('--context', $Context, 'apply', '-f', $storeFile)
    Remove-Item -Force -ErrorAction SilentlyContinue $storeFile
  }

  # A Gatekeeper webhook with failurePolicy=Fail must reject admission while unavailable.
  $webhook = Get-Json @('--context', $Context, 'get', 'validatingwebhookconfiguration', 'gatekeeper-validating-webhook-configuration', '-o', 'json')
  $failurePolicies = @($webhook.webhooks | ForEach-Object { $_.failurePolicy })
  if ($failurePolicies -notcontains 'Fail') { throw 'Gatekeeper validating webhook is not configured fail-closed.' }
  $controller = Get-Json @('--context', $Context, '-n', 'gatekeeper-system', 'get', 'deployment', 'gatekeeper-controller-manager', '-o', 'json')
  $replicas = [int]$controller.spec.replicas
  if ($replicas -lt 1) { throw 'Gatekeeper controller has no healthy replica to test.' }
  try {
    Invoke-Checked kubectl @('--context', $Context, '-n', 'gatekeeper-system', 'scale', 'deployment/gatekeeper-controller-manager', '--replicas=0')
    Start-Sleep -Seconds 15
    Assert-PrivilegedAdmissionDenied
  } finally {
    Invoke-Checked kubectl @('--context', $Context, '-n', 'gatekeeper-system', 'scale', 'deployment/gatekeeper-controller-manager', "--replicas=$replicas")
    Invoke-Checked kubectl @('--context', $Context, '-n', 'gatekeeper-system', 'rollout', 'status', 'deployment/gatekeeper-controller-manager', '--timeout=300s')
  }

  # Trigger a shell event and require Falco to emit a bounded, identifiable alert.
  $demoPods = Invoke-Captured kubectl @('--context', $Context, '-n', 'demo-dev', 'get', 'pods', '-l', 'app.kubernetes.io/name=demo-service', '-o', 'jsonpath={.items[*].metadata.name}')
  if ([string]::IsNullOrWhiteSpace($demoPods)) { throw 'No demo-service pod was found for the Falco trigger.' }
  $falcoPods = (Invoke-Captured kubectl @('--context', $Context, '-n', 'falco', 'get', 'pods', '-l', 'app.kubernetes.io/name=falco', '-o', 'jsonpath={.items[*].metadata.name}')).Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
  if ($falcoPods.Count -eq 0) { throw 'No Falco pod was found for the runtime trigger.' }
  $targetPod = $demoPods.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)[0]
  Invoke-Checked kubectl @('--context', $Context, '-n', 'demo-dev', 'exec', $targetPod, '--', 'sh', '-c', 'echo driftguard-falco-trigger')
  $deadline = (Get-Date).AddSeconds(30)
  $alert = $null
  do {
    foreach ($falcoPod in $falcoPods) {
      $logs = & kubectl --context $Context -n falco logs $falcoPod --since=35s --all-containers=true 2>$null
      if (($logs -join "`n") -match '(?i)(terminal shell|shell in container|falco)') { $alert = $logs -join "`n"; break }
    }
    if ($alert) { break }
    Start-Sleep -Seconds 3
  } while ((Get-Date) -lt $deadline)
  if (-not $alert) { throw 'Falco did not emit an identifiable alert within 30 seconds.' }

  # Query Loki through the Kubernetes API proxy and require the same trigger to be observable there.
  $logQuery = [uri]::EscapeDataString('{job="falco"} |= "driftguard-falco-trigger"')
  $lokiPath = "/api/v1/namespaces/monitoring/services/http:loki-gateway:80/proxy/loki/api/v1/query?query=$logQuery"
  $lokiResponse = Invoke-Captured kubectl @('--context', $Context, 'get', '--raw', $lokiPath) | ConvertFrom-Json
  if (-not $lokiResponse.data.result -or @($lokiResponse.data.result).Count -eq 0) {
    throw 'Falco emitted an alert, but the alert was not forwarded to Loki within 30 seconds.'
  }
  Write-Host 'Falco emitted and forwarded an identifiable alert within 30 seconds.'
}
Write-Host 'Add-on readiness checks passed. Runtime checks were skipped unless -RunMutationChecks was supplied.'
