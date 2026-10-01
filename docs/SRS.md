# Mini Choice Engine â€” SRS V2
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
