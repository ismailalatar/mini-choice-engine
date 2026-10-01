$ErrorActionPreference = "Stop"
$root = "D:\PROJECTS\WEB\mini-choice-engine"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Save-NoBom($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# ---------- README.md ----------
$readme = @'
# Mini Choice Engine — Decision Optimization Engine

A general-purpose Java engine for **decision-making under constraints**.
Given a scenario (resources, candidates, constraints, probabilities, costs, objective),
it generates all feasible combinations, scores them, ranks them, and explains the top solutions.

## Why
Originally a small "3 ambulances / 5 patients" exercise. Reworked into a scenario-agnostic
optimization engine that demonstrates:
OOP · Algorithms · Probability · Combinatorics · Optimization · Decision Modeling.

## Features
- JSON-based scenario definition (no code changes to add new domains)
- Hard constraints (feasibility) + placeholders for soft constraints (penalty)
- Expected-value scoring with configurable weights
- Deterministic ranking with stable tie-breaking
- Human-readable explanations for each top solution
- CLI: `validate` and `run`, plus full JSON export
- 30+ unit / golden tests

## Quick start
```cmd
mvn package
java -jar target\mini-choice-engine-2.0.0-SNAPSHOT.jar validate examples\ambulance.json
java -jar target\mini-choice-engine-2.0.0-SNAPSHOT.jar run examples\ambulance.json -n 5
java -jar target\mini-choice-engine-2.0.0-SNAPSHOT.jar run examples\ambulance.json -o examples\ambulance.result.json