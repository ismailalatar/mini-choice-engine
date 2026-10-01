# Complexity

Let:
- R = number of resources
- C = number of candidates
- N = number of generated combinations

## Combination count

For each resource we choose either to leave it idle or assign one unused candidate:

    N = sum_{k=0..R} C(R,k) * P(C,k)

Where C(R,k) picks which resources are used and P(C,k) picks the
ordered assignment of candidates.

Examples:

    R   C   N
    3   3   34
    3   5   136
    4   4   209
    5   5   1546
    6   6   13327

Upper bound: N = O((C+1)^R).

## Time

    Stage          Complexity
    Validation     O(R + C + P + K)          P=probabilities, K=costs
    Generation     O(N * R)
    Feasibility    O(N * R * T)              T=number of constraints
    Scoring        O(N * R)
    Ranking        O(N log N)
    Explaining     O(k)                      k=top solutions requested

Dominant term: O(N * R * T + N log N).

## Space

- Storage of all combinations: O(N * R)
- Current feasibility pass: O(R) extra
- Ranking copy: O(N)

## Safety cap

maxCombinations (default 1,000,000) bounds N at generation time.
Once reached, generation stops and result carries truncated=true.

## Scaling

R=5,  C=10 -> N = 63,591     trivial
R=8,  C=20 -> N > 1,000,000  cap triggers

For very large scenarios (R > 15 or C > 50), replace brute-force with
an ILP / branch-and-bound / DP solver.
The engine interface (DecisionEngine.decide) stays unchanged.
Only the CombinationGenerator implementation is swapped.