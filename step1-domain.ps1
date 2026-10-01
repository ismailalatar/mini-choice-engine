$ErrorActionPreference = "Stop"

$root = "D:\PROJECTS\WEB\mini-choice-engine"

# ---------- docs/SRS.md ----------
$srs = @'
# Mini Choice Engine — SRS V2
## Decision Optimization Engine

### 1. Objective
A general-purpose engine for decision-making under constraints.
Given a Scenario (resources, candidates, constraints, probabilities, costs, priorities, objective)
Produce: ranked feasible solutions with scores and explanations.

### 2. Scope
In-scope:
- Assignment-based decisions (Resource -> Candidate)
- Hard constraints (feasibility) + Soft constraints (penalty)
- Probabilistic outcomes (expected value)
- Weighted multi-objective scoring
- Explanation generation

Out-of-scope (MVP):
- GUI
- Machine Learning
- Persistence / DB
- Distributed solving

### 3. Functional Requirements
FR-1  Load Scenario from JSON.
FR-2  Validate Scenario (schema + semantic).
FR-3  Generate all feasible assignment combinations.
FR-4  Reject infeasible combinations via Hard Constraints.
FR-5  Evaluate each feasible solution:
      - ExpectedBenefit
      - Risk
      - TotalCost
      - SoftPenalty
FR-6  Compute Score via Objective (weighted sum, maximize/minimize).
FR-7  Rank solutions descending.
FR-8  Explain top solutions (why chosen, constraint hits, deltas vs next).
FR-9  Export results to JSON (solutions + explanations + metrics).
FR-10 Engine must be scenario-agnostic (no domain-specific code).

### 4. Non-Functional Requirements
NFR-1 Clean architecture (domain / engine / app / io / cli).
NFR-2 Unit tests cover domain + engine (>= 80% on engine).
NFR-3 Input validation with clear error messages.
NFR-4 Deterministic results (stable ordering on ties).
NFR-5 Separation between Engine API and CLI.
NFR-6 Documented algorithm + complexity.
NFR-7 Reproducible golden scenarios (JSON in -> JSON out).
NFR-8 Configurable safety cap: MaxCombinations (default 1_000_000).

### 5. Success Criteria
SRS -> Implementation -> Tests -> Results -> Documentation
Every FR must map to: code + test + example + documentation.

### 6. Scoring Model (Initial)
ExpectedBenefit = SUM( priority_norm * severity * success_probability )
Risk            = SUM( priority_norm * severity * (1 - success_probability) )
TotalCost       = SUM( cost )
SoftPenalty     = SUM( soft constraint violations )

Score = w.benefit      * ExpectedBenefit
      - w.risk         * Risk
      - w.cost         * TotalCost
      - w.softPenalty  * SoftPenalty
'@

Set-Content -Path "$root\docs\SRS.md" -Value $srs -Encoding UTF8


# ---------- domain/Resource.java ----------
$resource = @'
package com.minichoice.domain;

public record Resource(String id, String type, int capacity) {
    public Resource {
        if (id == null || id.isBlank()) throw new IllegalArgumentException("resource.id required");
        if (type == null || type.isBlank()) throw new IllegalArgumentException("resource.type required");
        if (capacity < 1) throw new IllegalArgumentException("resource.capacity must be >= 1");
    }
}
'@
Set-Content -Path "$root\src\main\java\com\minichoice\domain\Resource.java" -Value $resource -Encoding UTF8


# ---------- domain/Candidate.java ----------
$candidate = @'
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
Set-Content -Path "$root\src\main\java\com\minichoice\domain\Candidate.java" -Value $candidate -Encoding UTF8


# ---------- domain/ConstraintType.java ----------
$constraintType = @'
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
Set-Content -Path "$root\src\main\java\com\minichoice\domain\ConstraintType.java" -Value $constraintType -Encoding UTF8


# ---------- domain/Constraint.java ----------
$constraint = @'
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
Set-Content -Path "$root\src\main\java\com\minichoice\domain\Constraint.java" -Value $constraint -Encoding UTF8


# ---------- domain/Probability.java ----------
$probability = @'
package com.minichoice.domain;

public record Probability(String resourceId, String candidateId, double success) {
    public Probability {
        if (resourceId == null || resourceId.isBlank()) throw new IllegalArgumentException("probability.resourceId required");
        if (candidateId == null || candidateId.isBlank()) throw new IllegalArgumentException("probability.candidateId required");
        if (success < 0 || success > 1) throw new IllegalArgumentException("probability.success must be in [0,1]");
    }
}
'@
Set-Content -Path "$root\src\main\java\com\minichoice\domain\Probability.java" -Value $probability -Encoding UTF8


# ---------- domain/Cost.java ----------
$cost = @'
package com.minichoice.domain;

public record Cost(String resourceId, String candidateId, double cost) {
    public Cost {
        if (resourceId == null || resourceId.isBlank()) throw new IllegalArgumentException("cost.resourceId required");
        if (candidateId == null || candidateId.isBlank()) throw new IllegalArgumentException("cost.candidateId required");
        if (cost < 0) throw new IllegalArgumentException("cost.cost must be >= 0");
    }
}
'@
Set-Content -Path "$root\src\main\java\com\minichoice\domain\Cost.java" -Value $cost -Encoding UTF8


# ---------- domain/ObjectiveType.java ----------
$objectiveType = @'
package com.minichoice.domain;

public enum ObjectiveType {
    MAXIMIZE,
    MINIMIZE
}
'@
Set-Content -Path "$root\src\main\java\com\minichoice\domain\ObjectiveType.java" -Value $objectiveType -Encoding UTF8


# ---------- domain/Weights.java ----------
$weights = @'
package com.minichoice.domain;

public record Weights(double benefit, double risk, double cost, double softPenalty) {
    public Weights {
        if (benefit < 0 || risk < 0 || cost < 0 || softPenalty < 0)
            throw new IllegalArgumentException("weights must be >= 0");
    }
}
'@
Set-Content -Path "$root\src\main\java\com\minichoice\domain\Weights.java" -Value $weights -Encoding UTF8


# ---------- domain/Objective.java ----------
$objective = @'
package com.minichoice.domain;

public record Objective(ObjectiveType type, Weights weights) {
    public Objective {
        if (type == null) throw new IllegalArgumentException("objective.type required");
        if (weights == null) throw new IllegalArgumentException("objective.weights required");
    }
}
'@
Set-Content -Path "$root\src\main\java\com\minichoice\domain\Objective.java" -Value $objective -Encoding UTF8


# ---------- domain/Assignment.java ----------
$assignment = @'
package com.minichoice.domain;

public record Assignment(String resourceId, String candidateId) {
    public Assignment {
        if (resourceId == null || resourceId.isBlank()) throw new IllegalArgumentException("assignment.resourceId required");
        if (candidateId == null || candidateId.isBlank()) throw new IllegalArgumentException("assignment.candidateId required");
    }
}
'@
Set-Content -Path "$root\src\main\java\com\minichoice\domain\Assignment.java" -Value $assignment -Encoding UTF8


# ---------- domain/Scenario.java ----------
$scenario = @'
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
Set-Content -Path "$root\src\main\java\com\minichoice\domain\Scenario.java" -Value $scenario -Encoding UTF8


# ---------- domain/Solution.java ----------
$solution = @'
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
Set-Content -Path "$root\src\main\java\com\minichoice\domain\Solution.java" -Value $solution -Encoding UTF8


Write-Host ""
Write-Host "=== step1-domain.ps1 completed ===" -ForegroundColor Green
Get-ChildItem -Recurse -File "$root\src\main\java\com\minichoice\domain" | Select-Object Name
Get-ChildItem -File "$root\docs" | Select-Object Name