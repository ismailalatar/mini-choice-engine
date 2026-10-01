$root = "D:\PROJECTS\WEB\mini-choice-engine"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$content = @'
# Mini Choice Engine -- Decision Optimization Engine

A general-purpose Java engine for decision-making under constraints.

Input: resources, candidates, constraints, probabilities, costs, objective.
Output: ranked feasible solutions with scores and explanations.

## Why

Started as a small "3 ambulances / 5 patients" exercise.
Reworked into a scenario-agnostic optimization engine.

## Features

- JSON scenario definition (no code change to add new domains)
- Hard constraints (feasibility) + soft placeholder
- Expected-value scoring with configurable weights
- Deterministic ranking with stable tie-breaking
- Human-readable explanations
- CLI: validate and run, JSON export
- 30+ unit and golden tests

## Quick start

    mvn package
    java -jar target\mini-choice-engine-2.0.0-SNAPSHOT.jar validate examples\ambulance.json
    java -jar target\mini-choice-engine-2.0.0-SNAPSHOT.jar run examples\ambulance.json -n 5

## Layout

    src/main/java/com/minichoice/
      domain/        domain model (records, enums)
      engine/        generator, filter, scorer, ranker, explainer, engine
      validation/    scenario validator
      io/json/       jackson loaders
      cli/           picocli commands
    docs/            SRS, ALGORITHM, COMPLEXITY, EXAMPLES
    examples/        ambulance.json

## Documentation

- docs/SRS.md
- docs/ALGORITHM.md
- docs/COMPLEXITY.md
- docs/EXAMPLES.md

## Requirements

- Java 21
- Maven 3.9+
'@
[System.IO.File]::WriteAllText("$root\README.md", $content, $utf8)
Write-Host "README.md created"