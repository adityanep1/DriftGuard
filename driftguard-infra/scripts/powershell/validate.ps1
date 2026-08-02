$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Require-Command([string]$Command) {
  if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
    throw "Required validation tool is unavailable: $Command"
  }
}

function Invoke-Required([string]$Command, [string[]]$Arguments) {
  Write-Host "> $Command $($Arguments -join ' ')"
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

foreach ($command in @('terraform', 'python', 'tflint', 'tfsec', 'checkov', 'conftest', 'kubeconform')) {
  Require-Command $command
}

Push-Location $infraRoot
try { Invoke-Required terraform @('fmt', '-check', '-recursive') } finally { Pop-Location }
$roots = @(
  (Join-Path $infraRoot 'bootstrap'),
  (Join-Path $infraRoot 'modules/networking'),
  (Join-Path $infraRoot 'modules/networking/examples/basic'),
  (Join-Path $infraRoot 'modules/eks'),
  (Join-Path $infraRoot 'modules/iam'),
  (Join-Path $infraRoot 'modules/ecr'),
  (Join-Path $infraRoot 'modules/ecr/examples/basic'),
  (Join-Path $infraRoot 'modules/dns'),
  (Join-Path $infraRoot 'modules/addons-bootstrap'),
  (Join-Path $infraRoot 'modules/github-oidc'),
  (Join-Path $infraRoot 'live/dev'),
  (Join-Path $infraRoot 'live/staging'),
  (Join-Path $infraRoot 'live/prod')
)
foreach ($root in $roots) {
  Push-Location $root
  try {
    Invoke-Required terraform @('init', '-backend=false', '-input=false', '-upgrade=false')
    Invoke-Required terraform @('validate')
    Invoke-Required tflint @('--force')
  } finally { Pop-Location }
}

Push-Location $infraRoot
try { Invoke-Required python @('-m', 'pytest', 'policies/python', '-q') } finally { Pop-Location }
Invoke-Required tfsec @($infraRoot, '--exclude-downloaded-modules')
Invoke-Required checkov @('-d', $infraRoot, '--quiet')
Push-Location $infraRoot
try {
  Invoke-Required conftest @('test', '--all-namespaces', '--policy', 'policies', 'policies/tests/valid-plan.json')
  & conftest test --all-namespaces --policy policies policies/tests/invalid-security-plan.json
  if ($LASTEXITCODE -eq 0) { throw 'Expected invalid security fixture to fail conformance' }
} finally { Pop-Location }
$yaml = Get-ChildItem -Path (Join-Path $infraRoot '..\driftguard-gitops') -Recurse -Include *.yaml,*.yml |
  Where-Object {
    $_.Name -notin @('versions.yaml', 'demo-service-slo-rules.yaml', 'demo-service-slo-test.yaml', '.pre-commit-config.yaml', 'kustomization.yaml') -and
    $_.FullName -notlike '*\.github\*'
  }
if ($yaml.Count -gt 0) {
  $kubeconformArguments = @('-strict', '-ignore-missing-schemas', '-summary') + @($yaml | ForEach-Object { $_.FullName })
  Invoke-Required kubeconform $kubeconformArguments
}
Write-Host 'Validation completed without applying infrastructure or contacting AWS.'
