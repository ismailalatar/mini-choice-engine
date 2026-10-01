$root = "D:\PROJECTS\WEB\mini-choice-engine"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$content = @'
# Algorithm

The engine runs a deterministic 5-stage pipeline:

1. Validation       -- ScenarioValidator
2. Generation       -- CombinationGenerator (backtracking)
3. Feasibility      -- FeasibilityFilter (hard constraints)
4. Scoring          -- Scorer (expected value + weighted objective)
5. Ranking + Explain -- Ranker + Explainer

## 1. Validation

Checks the scenario is semantically coherent:
- non-empty resources and candidates
- unique ids
- probabilities/costs refer to known ids

Schema validation is enforced by Jackson during loading.

## 2. Generation

Backtracking over resources.

At each resource we branch into:
- leave the resource idle
- assign it to any candidate not yet used

The usedCandidates boolean array guarantees a candidate is never assigned twice.
An empty combination is a valid solution (all resources idle).

Safety cap: maxCombinations (default 1,000,000).
If reached, generation stops and truncated=true is returned.

## 3. Feasibility (hard constraints)

Each generated combination is checked against all hard constraints:
- MAX_ASSIGNMENTS_PER_RESOURCE
- MAX_ASSIGNMENTS_PER_CANDIDATE
- MAX_TOTAL_ASSIGNMENTS
- MIN_PRIORITY_THRESHOLD
- MAX_TOTAL_COST
- CANDIDATE_REQUIRES_RESOURCE_TYPE

Any violation means the solution is discarded.

## 4. Scoring

For each assignment (r, c):

    pn   = c.priority / max(priority)
    p    = probability(r, c)      (default 0.5 if missing)
    cost = cost(r, c)             (default 0.0 if missing)

    EB   = pn * c.severity * p
    Risk = pn * c.severity * (1 - p)

Aggregated per solution:

    ExpectedBenefit = sum of EB
    Risk            = sum of Risk
    TotalCost       = sum of cost
    SoftPenalty     = sum of soft violations   (0 for now)

    Score = w.benefit      * ExpectedBenefit
          - w.risk         * Risk
          - w.cost         * TotalCost
          - w.softPenalty  * SoftPenalty

If objective.type == MINIMIZE, the final score is negated so that
the Ranker always sorts descending.

## 5. Ranking and Explanation

Ranker sorts by:
1. score desc
2. fewer assignments first
3. lexicographic comparison of normalized "R->C" strings

Tie-breaking is total. No two distinct solutions share the same rank order.

Explainer produces for each solution:
- all metric values
- the assignment list
- the score advantage over the next solution

## Determinism

No randomness. Floating-point formatting uses Locale.ROOT.
Same JSON in = same output bytes out.
'@
[System.IO.File]::WriteAllText("$root\docs\ALGORITHM.md", $content, $utf8)
Write-Host "ALGORITHM.md created"