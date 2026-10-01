# Examples

## 1. Ambulance dispatch (golden scenario)

Input file: examples/ambulance.json

- 3 ambulances (A1, A2, A3)
- 5 patients (P1..P5) with priorities 5,4,5,2,3
- hard constraints:
    MAX_ASSIGNMENTS_PER_RESOURCE = 1
    MAX_TOTAL_ASSIGNMENTS        = 3
- per-(resource,patient) success probabilities
- non-zero costs for a few pairs
- objective: MAXIMIZE with weights {benefit=1.0, risk=0.5, cost=0.05}

Run:

    java -jar target\mini-choice-engine-2.0.0-SNAPSHOT.jar run examples\ambulance.json -n 5

Observed top-5 (deterministic):

    #1  Score=1.465  EB=1.720  Risk=0.510  Cost=0.00   A1->P3, A2->P1, A3->P2
    #2  Score=1.375  EB=1.600  Risk=0.450  Cost=0.00   A1->P3, A2->P1, A3->P5
    #3  Score=1.371  EB=1.657  Risk=0.573  Cost=0.00   A1->P3, A2->P2, A3->P1
    #4  Score=1.270  EB=1.957  Risk=0.274  Cost=11.00  A1->P2, A2->P1, A3->P3
    #5  Score=1.244  EB=1.389  Risk=0.291  Cost=0.00   A1->P2, A2->P1, A3->P5

Note how solution #4 has the highest ExpectedBenefit (1.957) but pays for it
with 11.0 cost; the weighted objective pushes it to 4th place.
This is exactly what decision modeling should surface.

## 2. Full output to JSON

    java -jar target\mini-choice-engine-2.0.0-SNAPSHOT.jar run examples\ambulance.json -o examples\ambulance.result.json

Output contains:
- generatedCombinations (before constraints)
- feasibleCombinations (after constraints)
- truncated flag
- rankedSolutions[] with all metrics + explanations

## 3. Validation only

    java -jar target\mini-choice-engine-2.0.0-SNAPSHOT.jar validate examples\ambulance.json

Prints OK + scenario id, or lists each error with a code.

## 4. Adding a new scenario

Duplicate examples\ambulance.json, change ids and values.
No code change is required. The engine is scenario-agnostic.

Supported constraint types:

    MAX_ASSIGNMENTS_PER_RESOURCE     value: number
    MAX_ASSIGNMENTS_PER_CANDIDATE    value: number
    MAX_TOTAL_ASSIGNMENTS            value: number
    MIN_PRIORITY_THRESHOLD           value: number
    MAX_TOTAL_COST                   value: number
    CANDIDATE_REQUIRES_RESOURCE_TYPE stringValue: string

Objective types: MAXIMIZE, MINIMIZE.