$ErrorActionPreference = "Stop"
$root = "D:\PROJECTS\WEB\mini-choice-engine"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Save-NoBom($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# ---------- engine/GenerationResult.java ----------
$genResult = @'
package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import java.util.List;

public record GenerationResult(List<List<Assignment>> combinations, boolean truncated) {
    public GenerationResult {
        combinations = List.copyOf(combinations);
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\engine\GenerationResult.java" $genResult

# ---------- engine/CombinationGenerator.java ----------
$gen = @'
package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Candidate;
import com.minichoice.domain.Resource;
import com.minichoice.domain.Scenario;

import java.util.ArrayList;
import java.util.List;

/**
 * Generates all possible assignment combinations via backtracking.
 *
 * Model (MVP):
 *  - Each resource can be assigned at most ONE candidate.
 *  - Each candidate can be assigned to at most ONE resource (enforced by backtracking).
 *  - Empty combinations are allowed (a valid "do nothing" solution).
 *
 * Complexity: O((C+1)^R) upper bound, with C=candidates, R=resources.
 * Pruned by the usedCandidates set at each level.
 */
public final class CombinationGenerator {

    public GenerationResult generate(Scenario scenario, int maxCombinations) {
        if (maxCombinations < 1) {
            throw new IllegalArgumentException("maxCombinations must be >= 1");
        }

        List<Resource> resources = scenario.resources();
        List<Candidate> candidates = scenario.candidates();

        List<List<Assignment>> result = new ArrayList<>();
        boolean[] truncated = {false};

        backtrack(resources, candidates, 0, new ArrayList<>(), new boolean[candidates.size()],
                  result, maxCombinations, truncated);

        return new GenerationResult(result, truncated[0]);
    }

    private void backtrack(List<Resource> resources,
                           List<Candidate> candidates,
                           int resourceIndex,
                           List<Assignment> current,
                           boolean[] usedCandidates,
                           List<List<Assignment>> result,
                           int maxCombinations,
                           boolean[] truncated) {
        if (truncated[0]) return;

        if (resourceIndex == resources.size()) {
            result.add(new ArrayList<>(current));
            if (result.size() >= maxCombinations) {
                truncated[0] = true;
            }
            return;
        }

        Resource resource = resources.get(resourceIndex);

        // Option 1: this resource is left idle
        backtrack(resources, candidates, resourceIndex + 1, current, usedCandidates,
                  result, maxCombinations, truncated);
        if (truncated[0]) return;

        // Option 2: this resource serves one candidate
        for (int c = 0; c < candidates.size(); c++) {
            if (usedCandidates[c]) continue;
            usedCandidates[c] = true;
            current.add(new Assignment(resource.id(), candidates.get(c).id()));

            backtrack(resources, candidates, resourceIndex + 1, current, usedCandidates,
                      result, maxCombinations, truncated);

            current.remove(current.size() - 1);
            usedCandidates[c] = false;

            if (truncated[0]) return;
        }
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\engine\CombinationGenerator.java" $gen

# ---------- engine/FeasibilityResult.java ----------
$feasResult = @'
package com.minichoice.engine;

import java.util.List;

public record FeasibilityResult(boolean feasible, List<String> violations) {
    public FeasibilityResult {
        violations = List.copyOf(violations);
    }

    public static FeasibilityResult ok() {
        return new FeasibilityResult(true, List.of());
    }

    public static FeasibilityResult fail(List<String> violations) {
        return new FeasibilityResult(false, violations);
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\engine\FeasibilityResult.java" $feasResult

# ---------- engine/FeasibilityFilter.java ----------
$filter = @'
package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Candidate;
import com.minichoice.domain.Constraint;
import com.minichoice.domain.ConstraintType;
import com.minichoice.domain.Cost;
import com.minichoice.domain.Resource;
import com.minichoice.domain.Scenario;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Applies HARD constraints. If any is violated -> solution is infeasible.
 * Soft constraints are NOT handled here (they contribute to SoftPenalty in Scorer).
 */
public final class FeasibilityFilter {

    public FeasibilityResult check(List<Assignment> assignments, Scenario scenario) {
        List<String> violations = new ArrayList<>();

        Map<String, Resource> resourcesById = indexById(scenario.resources(), Resource::id);
        Map<String, Candidate> candidatesById = indexById(scenario.candidates(), Candidate::id);
        Map<String, Double> costByPair = buildCostIndex(scenario.costs());

        // counts
        Map<String, Integer> perResource = new HashMap<>();
        Map<String, Integer> perCandidate = new HashMap<>();
        double totalCost = 0.0;

        for (Assignment a : assignments) {
            Resource r = resourcesById.get(a.resourceId());
            Candidate c = candidatesById.get(a.candidateId());

            if (r == null) {
                violations.add("Unknown resourceId: " + a.resourceId());
                continue;
            }
            if (c == null) {
                violations.add("Unknown candidateId: " + a.candidateId());
                continue;
            }

            perResource.merge(r.id(), 1, Integer::sum);
            perCandidate.merge(c.id(), 1, Integer::sum);
            totalCost += costByPair.getOrDefault(key(r.id(), c.id()), 0.0);
        }

        int totalAssignments = assignments.size();

        for (Constraint c : scenario.constraints()) {
            ConstraintType t = c.type();
            switch (t) {
                case MAX_ASSIGNMENTS_PER_RESOURCE -> {
                    int max = (int) c.value();
                    perResource.forEach((rid, cnt) -> {
                        if (cnt > max)
                            violations.add("Resource " + rid + " exceeded MAX_ASSIGNMENTS_PER_RESOURCE (" + cnt + " > " + max + ")");
                    });
                }
                case MAX_ASSIGNMENTS_PER_CANDIDATE -> {
                    int max = (int) c.value();
                    perCandidate.forEach((cid, cnt) -> {
                        if (cnt > max)
                            violations.add("Candidate " + cid + " exceeded MAX_ASSIGNMENTS_PER_CANDIDATE (" + cnt + " > " + max + ")");
                    });
                }
                case MAX_TOTAL_ASSIGNMENTS -> {
                    if (totalAssignments > c.value())
                        violations.add("Total assignments exceeded MAX_TOTAL_ASSIGNMENTS (" + totalAssignments + " > " + (int) c.value() + ")");
                }
                case MIN_PRIORITY_THRESHOLD -> {
                    int min = (int) c.value();
                    for (Assignment a : assignments) {
                        Candidate cand = candidatesById.get(a.candidateId());
                        if (cand != null && cand.priority() < min)
                            violations.add("Candidate " + cand.id() + " priority " + cand.priority() + " < MIN_PRIORITY_THRESHOLD " + min);
                    }
                }
                case MAX_TOTAL_COST -> {
                    if (totalCost > c.value())
                        violations.add("Total cost " + totalCost + " > MAX_TOTAL_COST " + c.value());
                }
                case CANDIDATE_REQUIRES_RESOURCE_TYPE -> {
                    String requiredType = c.stringValue();
                    for (Assignment a : assignments) {
                        Resource r = resourcesById.get(a.resourceId());
                        if (r != null && !r.type().equals(requiredType))
                            violations.add("Candidate " + a.candidateId() + " requires resource type " + requiredType + " but got " + r.type());
                    }
                }
            }
        }

        return violations.isEmpty() ? FeasibilityResult.ok() : FeasibilityResult.fail(violations);
    }

    private static <T> Map<String, T> indexById(List<T> list, java.util.function.Function<T, String> idFn) {
        Map<String, T> map = new HashMap<>();
        for (T item : list) map.put(idFn.apply(item), item);
        return map;
    }

    private static Map<String, Double> buildCostIndex(List<Cost> costs) {
        Map<String, Double> map = new HashMap<>();
        for (Cost c : costs) map.put(key(c.resourceId(), c.candidateId()), c.cost());
        return map;
    }

    private static String key(String r, String c) { return r + "::" + c; }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\engine\FeasibilityFilter.java" $filter

# ---------- test/engine/CombinationGeneratorTest.java ----------
$genTest = @'
package com.minichoice.engine;

import com.minichoice.domain.*;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class CombinationGeneratorTest {

    private Scenario scenarioWith(int r, int c) {
        List<Resource> resources = new java.util.ArrayList<>();
        for (int i = 1; i <= r; i++) resources.add(new Resource("R" + i, "type", 1));

        List<Candidate> candidates = new java.util.ArrayList<>();
        for (int i = 1; i <= c; i++) candidates.add(new Candidate("C" + i, 1, 0.5, 1.0));

        return new Scenario(
            "test",
            resources,
            candidates,
            List.of(),
            List.of(),
            List.of(),
            new Objective(ObjectiveType.MAXIMIZE, new Weights(1, 0, 0, 0))
        );
    }

    @Test
    void zero_resources_yields_empty_combination() {
        var g = new CombinationGenerator();
        var res = g.generate(scenarioWith(0, 3), 1000);
        assertThat(res.combinations()).hasSize(1);
        assertThat(res.combinations().get(0)).isEmpty();
    }

    @Test
    void two_resources_two_candidates_yields_7_combinations() {
        var g = new CombinationGenerator();
        var res = g.generate(scenarioWith(2, 2), 1000);
        // [] + 4 single + 2 double = 7
        assertThat(res.combinations()).hasSize(7);
    }

    @Test
    void three_resources_three_candidates_yields_16_combinations() {
        var g = new CombinationGenerator();
        var res = g.generate(scenarioWith(3, 3), 1000);
        // sum_{k=0..3} C(3,k)*P(3,k) = 1 + 9 + 18 + 6 = 34
        assertThat(res.combinations()).hasSize(34);
    }

    @Test
    void max_combinations_truncates() {
        var g = new CombinationGenerator();
        var res = g.generate(scenarioWith(3, 3), 5);
        assertThat(res.combinations()).hasSize(5);
        assertThat(res.truncated()).isTrue();
    }
}
'@
Save-NoBom "$root\src\test\java\com\minichoice\engine\CombinationGeneratorTest.java" $genTest

# ---------- test/engine/FeasibilityFilterTest.java ----------
$feasTest = @'
package com.minichoice.engine;

import com.minichoice.domain.*;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class FeasibilityFilterTest {

    private Scenario baseScenario(List<Constraint> constraints, List<Cost> costs) {
        return new Scenario(
            "t",
            List.of(
                new Resource("A1", "ambulance", 1),
                new Resource("A2", "ambulance", 1),
                new Resource("H1", "helicopter", 1)
            ),
            List.of(
                new Candidate("P1", 5, 0.9, 4.0),
                new Candidate("P2", 1, 0.5, 2.0)
            ),
            constraints,
            List.of(),
            costs,
            new Objective(ObjectiveType.MAXIMIZE, new Weights(1, 0, 0, 0))
        );
    }

    @Test
    void empty_assignments_are_feasible() {
        var f = new FeasibilityFilter();
        var s = baseScenario(List.of(), List.of());
        assertThat(f.check(List.of(), s).feasible()).isTrue();
    }

    @Test
    void unknown_resource_is_infeasible() {
        var f = new FeasibilityFilter();
        var s = baseScenario(List.of(), List.of());
        var r = f.check(List.of(new Assignment("X", "P1")), s);
        assertThat(r.feasible()).isFalse();
        assertThat(r.violations()).anyMatch(v -> v.contains("Unknown resourceId"));
    }

    @Test
    void max_total_assignments_blocks() {
        var f = new FeasibilityFilter();
        var s = baseScenario(List.of(new Constraint(ConstraintType.MAX_TOTAL_ASSIGNMENTS, 1, null)), List.of());
        var r = f.check(List.of(
            new Assignment("A1", "P1"),
            new Assignment("A2", "P2")
        ), s);
        assertThat(r.feasible()).isFalse();
    }

    @Test
    void min_priority_threshold_blocks() {
        var f = new FeasibilityFilter();
        var s = baseScenario(List.of(new Constraint(ConstraintType.MIN_PRIORITY_THRESHOLD, 3, null)), List.of());
        var r = f.check(List.of(new Assignment("A1", "P2")), s);
        assertThat(r.feasible()).isFalse();
    }

    @Test
    void max_total_cost_blocks() {
        var f = new FeasibilityFilter();
        var costs = List.of(new Cost("A1", "P1", 100.0));
        var s = baseScenario(List.of(new Constraint(ConstraintType.MAX_TOTAL_COST, 50, null)), costs);
        var r = f.check(List.of(new Assignment("A1", "P1")), s);
        assertThat(r.feasible()).isFalse();
    }

    @Test
    void requires_resource_type_blocks() {
        var f = new FeasibilityFilter();
        var s = baseScenario(List.of(new Constraint(ConstraintType.CANDIDATE_REQUIRES_RESOURCE_TYPE, 0, "helicopter")), List.of());
        var r = f.check(List.of(new Assignment("A1", "P1")), s);
        assertThat(r.feasible()).isFalse();
        assertThat(r.violations()).anyMatch(v -> v.contains("requires resource type"));
    }

    @Test
    void valid_assignment_passes() {
        var f = new FeasibilityFilter();
        var s = baseScenario(List.of(
            new Constraint(ConstraintType.MAX_TOTAL_ASSIGNMENTS, 2, null)
        ), List.of(new Cost("A1", "P1", 10.0)));
        var r = f.check(List.of(
            new Assignment("A1", "P1"),
            new Assignment("A2", "P2")
        ), s);
        assertThat(r.feasible()).isTrue();
    }
}
'@
Save-NoBom "$root\src\test\java\com\minichoice\engine\FeasibilityFilterTest.java" $feasTest

Write-Host ""
Write-Host "=== step2-engine.ps1 completed ===" -ForegroundColor Green
Get-ChildItem -File "$root\src\main\java\com\minichoice\engine" | Select-Object Name
Get-ChildItem -File "$root\src\test\java\com\minichoice\engine" | Select-Object Name