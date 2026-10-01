$ErrorActionPreference = "Stop"
$root = "D:\PROJECTS\WEB\mini-choice-engine"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Save-NoBom($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# إعادة كتابة ملفات domain بدون BOM
$domainDir = "$root\src\main\java\com\minichoice\domain"

$files = @{
  "Resource.java" = @'
package com.minichoice.domain;

public record Resource(String id, String type, int capacity) {
    public Resource {
        if (id == null || id.isBlank()) throw new IllegalArgumentException("resource.id required");
        if (type == null || type.isBlank()) throw new IllegalArgumentException("resource.type required");
        if (capacity < 1) throw new IllegalArgumentException("resource.capacity must be >= 1");
    }
}
'@

  "Candidate.java" = @'
package com.minichoice.domain;

public record Candidate(String id, int priority, double severity, double distance) {
    public Candidate {
        if (id == null || id.isBlank()) throw new IllegalArgumentException("candidate.id required");
        if (priority < 0) throw new IllegalArgumentException("candidate.priority must be >= 0");
        if (severity < 0 || severity > 1) throw new IllegalArgumentException("candidate.severity must be in [0,1]");
        if (distance < 0) throw new IllegalArgumentException("candidate.distance must be >= 0");
    }
}
'@

  "ConstraintType.java" = @'
package com.minichoice.domain;

public enum ConstraintType {
    MAX_ASSIGNMENTS_PER_RESOURCE,
    MAX_ASSIGNMENTS_PER_CANDIDATE,
    MAX_TOTAL_ASSIGNMENTS,
    MIN_PRIORITY_THRESHOLD,
    MAX_TOTAL_COST,
    CANDIDATE_REQUIRES_RESOURCE_TYPE
}
'@

  "Constraint.java" = @'
package com.minichoice.domain;

public record Constraint(ConstraintType type, double value, String stringValue) {
    public Constraint {
        if (type == null) throw new IllegalArgumentException("constraint.type required");
    }

    public static Constraint of(String type, double value) {
        return new Constraint(ConstraintType.valueOf(type), value, null);
    }

    public static Constraint of(String type, String stringValue) {
        return new Constraint(ConstraintType.valueOf(type), 0, stringValue);
    }
}
'@

  "Probability.java" = @'
package com.minichoice.domain;

public record Probability(String resourceId, String candidateId, double success) {
    public Probability {
        if (resourceId == null || resourceId.isBlank()) throw new IllegalArgumentException("probability.resourceId required");
        if (candidateId == null || candidateId.isBlank()) throw new IllegalArgumentException("probability.candidateId required");
        if (success < 0 || success > 1) throw new IllegalArgumentException("probability.success must be in [0,1]");
    }
}
'@

  "Cost.java" = @'
package com.minichoice.domain;

public record Cost(String resourceId, String candidateId, double cost) {
    public Cost {
        if (resourceId == null || resourceId.isBlank()) throw new IllegalArgumentException("cost.resourceId required");
        if (candidateId == null || candidateId.isBlank()) throw new IllegalArgumentException("cost.candidateId required");
        if (cost < 0) throw new IllegalArgumentException("cost.cost must be >= 0");
    }
}
'@

  "ObjectiveType.java" = @'
package com.minichoice.domain;

public enum ObjectiveType {
    MAXIMIZE,
    MINIMIZE
}
'@

  "Weights.java" = @'
package com.minichoice.domain;

public record Weights(double benefit, double risk, double cost, double softPenalty) {
    public Weights {
        if (benefit < 0 || risk < 0 || cost < 0 || softPenalty < 0)
            throw new IllegalArgumentException("weights must be >= 0");
    }
}
'@

  "Objective.java" = @'
package com.minichoice.domain;

public record Objective(ObjectiveType type, Weights weights) {
    public Objective {
        if (type == null) throw new IllegalArgumentException("objective.type required");
        if (weights == null) throw new IllegalArgumentException("objective.weights required");
    }
}
'@

  "Assignment.java" = @'
package com.minichoice.domain;

public record Assignment(String resourceId, String candidateId) {
    public Assignment {
        if (resourceId == null || resourceId.isBlank()) throw new IllegalArgumentException("assignment.resourceId required");
        if (candidateId == null || candidateId.isBlank()) throw new IllegalArgumentException("assignment.candidateId required");
    }
}
'@

  "Scenario.java" = @'
package com.minichoice.domain;

import java.util.List;
import java.util.Objects;

public record Scenario(
    String scenarioId,
    List<Resource> resources,
    List<Candidate> candidates,
    List<Constraint> constraints,
    List<Probability> probabilities,
    List<Cost> costs,
    Objective objective
) {
    public Scenario {
        Objects.requireNonNull(scenarioId, "scenarioId");
        resources     = List.copyOf(Objects.requireNonNullElse(resources, List.of()));
        candidates    = List.copyOf(Objects.requireNonNullElse(candidates, List.of()));
        constraints   = List.copyOf(Objects.requireNonNullElse(constraints, List.of()));
        probabilities = List.copyOf(Objects.requireNonNullElse(probabilities, List.of()));
        costs         = List.copyOf(Objects.requireNonNullElse(costs, List.of()));
        Objects.requireNonNull(objective, "objective");
    }
}
'@

  "Solution.java" = @'
package com.minichoice.domain;

import java.util.List;

public record Solution(
    List<Assignment> assignments,
    double expectedBenefit,
    double risk,
    double totalCost,
    double softPenalty,
    double score,
    List<String> explanation
) {
    public Solution {
        assignments = List.copyOf(assignments);
        explanation = List.copyOf(explanation);
    }
}
'@
}

foreach ($name in $files.Keys) {
    Save-NoBom "$domainDir\$name" $files[$name]
    Write-Host "Rewritten: $name" -ForegroundColor Yellow
}

# SRS.md بدون BOM
$srsPath = "$root\docs\SRS.md"
if (Test-Path $srsPath) {
    $srsContent = [System.IO.File]::ReadAllText($srsPath)
    Save-NoBom $srsPath $srsContent
    Write-Host "Rewritten: docs\SRS.md" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== fix-bom.ps1 completed ===" -ForegroundColor Green