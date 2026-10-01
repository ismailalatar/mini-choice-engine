$ErrorActionPreference = "Stop"
$root = "D:\PROJECTS\WEB\mini-choice-engine"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Save-NoBom($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# ---------- engine/DecisionResult.java ----------
$dr = @'
package com.minichoice.engine;

import com.minichoice.domain.Solution;

import java.util.List;

public record DecisionResult(
    int generatedCombinations,
    int feasibleCombinations,
    boolean truncated,
    List<Solution> rankedSolutions
) {
    public DecisionResult {
        rankedSolutions = List.copyOf(rankedSolutions);
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\engine\DecisionResult.java" $dr


# ---------- engine/DecisionEngine.java ----------
$engine = @'
package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Scenario;
import com.minichoice.domain.Solution;

import java.util.ArrayList;
import java.util.List;

/**
 * Orchestrates the full pipeline:
 *   generate -> feasibility filter -> score -> rank -> explain
 *
 * Deterministic: no randomness, stable ordering.
 */
public final class DecisionEngine {

    public static final int DEFAULT_MAX_COMBINATIONS = 1_000_000;

    private final CombinationGenerator generator;
    private final FeasibilityFilter filter;
    private final Scorer scorer;
    private final Ranker ranker;
    private final Explainer explainer;
    private final int maxCombinations;

    public DecisionEngine() {
        this(DEFAULT_MAX_COMBINATIONS);
    }

    public DecisionEngine(int maxCombinations) {
        this.generator = new CombinationGenerator();
        this.filter = new FeasibilityFilter();
        this.scorer = new Scorer();
        this.ranker = new Ranker();
        this.explainer = new Explainer();
        this.maxCombinations = maxCombinations;
    }

    public DecisionResult decide(Scenario scenario) {
        GenerationResult gen = generator.generate(scenario, maxCombinations);

        List<Solution> solutions = new ArrayList<>();
        for (List<Assignment> combo : gen.combinations()) {
            FeasibilityResult fr = filter.check(combo, scenario);
            if (!fr.feasible()) continue;

            Evaluation ev = scorer.evaluate(combo, scenario);
            Solution s = new Solution(
                combo,
                ev.expectedBenefit(),
                ev.risk(),
                ev.totalCost(),
                ev.softPenalty(),
                ev.score(),
                List.of()
            );
            solutions.add(s);
        }

        List<Solution> ranked = ranker.rank(solutions);

        // attach explanations
        List<Solution> withExplanations = new ArrayList<>(ranked.size());
        for (int i = 0; i < ranked.size(); i++) {
            Solution cur = ranked.get(i);
            Solution next = (i + 1 < ranked.size()) ? ranked.get(i + 1) : null;
            List<String> explanation = explainer.explain(cur, next);
            withExplanations.add(new Solution(
                cur.assignments(),
                cur.expectedBenefit(),
                cur.risk(),
                cur.totalCost(),
                cur.softPenalty(),
                cur.score(),
                explanation
            ));
        }

        return new DecisionResult(
            gen.combinations().size(),
            withExplanations.size(),
            gen.truncated(),
            withExplanations
        );
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\engine\DecisionEngine.java" $engine


# ---------- validation/ValidationError.java ----------
$ve = @'
package com.minichoice.validation;

public record ValidationError(String code, String message) {
    @Override
    public String toString() { return code + ": " + message; }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\validation\ValidationError.java" $ve


# ---------- validation/ValidationResult.java ----------
$vr = @'
package com.minichoice.validation;

import java.util.List;

public record ValidationResult(boolean valid, List<ValidationError> errors) {
    public ValidationResult {
        errors = List.copyOf(errors);
    }

    public static ValidationResult ok() { return new ValidationResult(true, List.of()); }
    public static ValidationResult fail(List<ValidationError> errors) {
        return new ValidationResult(false, errors);
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\validation\ValidationResult.java" $vr


# ---------- validation/ScenarioValidator.java ----------
$validator = @'
package com.minichoice.validation;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Candidate;
import com.minichoice.domain.Cost;
import com.minichoice.domain.Probability;
import com.minichoice.domain.Resource;
import com.minichoice.domain.Scenario;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Semantic validation. Structural validation is handled by Jackson.
 * Detects:
 *  - duplicate resource / candidate ids
 *  - probabilities/costs referencing unknown ids
 *  - empty resources / candidates
 */
public final class ScenarioValidator {

    public ValidationResult validate(Scenario s) {
        List<ValidationError> errors = new ArrayList<>();

        if (s.scenarioId() == null || s.scenarioId().isBlank()) {
            errors.add(new ValidationError("SCENARIO_ID_MISSING", "scenarioId is required"));
        }

        if (s.resources().isEmpty()) {
            errors.add(new ValidationError("NO_RESOURCES", "at least one resource is required"));
        }
        if (s.candidates().isEmpty()) {
            errors.add(new ValidationError("NO_CANDIDATES", "at least one candidate is required"));
        }

        Set<String> resourceIds = new HashSet<>();
        for (Resource r : s.resources()) {
            if (!resourceIds.add(r.id())) {
                errors.add(new ValidationError("DUPLICATE_RESOURCE", "duplicate resource id: " + r.id()));
            }
        }

        Set<String> candidateIds = new HashSet<>();
        for (Candidate c : s.candidates()) {
            if (!candidateIds.add(c.id())) {
                errors.add(new ValidationError("DUPLICATE_CANDIDATE", "duplicate candidate id: " + c.id()));
            }
        }

        for (Probability p : s.probabilities()) {
            if (!resourceIds.contains(p.resourceId())) {
                errors.add(new ValidationError("PROB_UNKNOWN_RESOURCE",
                    "probability references unknown resource: " + p.resourceId()));
            }
            if (!candidateIds.contains(p.candidateId())) {
                errors.add(new ValidationError("PROB_UNKNOWN_CANDIDATE",
                    "probability references unknown candidate: " + p.candidateId()));
            }
        }

        for (Cost c : s.costs()) {
            if (!resourceIds.contains(c.resourceId())) {
                errors.add(new ValidationError("COST_UNKNOWN_RESOURCE",
                    "cost references unknown resource: " + c.resourceId()));
            }
            if (!candidateIds.contains(c.candidateId())) {
                errors.add(new ValidationError("COST_UNKNOWN_CANDIDATE",
                    "cost references unknown candidate: " + c.candidateId()));
            }
        }

        return errors.isEmpty() ? ValidationResult.ok() : ValidationResult.fail(errors);
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\validation\ScenarioValidator.java" $validator


# ---------- io/json/ScenarioLoader.java ----------
$loader = @'
package com.minichoice.io.json;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;
import com.minichoice.domain.Scenario;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

public final class ScenarioLoader {

    private final ObjectMapper mapper;

    public ScenarioLoader() {
        this.mapper = JsonMapper.builder()
            .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .build();
    }

    public Scenario loadFromFile(Path path) throws IOException {
        try (InputStream in = Files.newInputStream(path)) {
            return mapper.readValue(in, Scenario.class);
        }
    }

    public Scenario loadFromString(String json) throws IOException {
        return mapper.readValue(json, Scenario.class);
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\io\json\ScenarioLoader.java" $loader


# ---------- io/json/ResultWriter.java ----------
$writer = @'
package com.minichoice.io.json;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.json.JsonMapper;
import com.minichoice.engine.DecisionResult;

import java.io.IOException;
import java.io.OutputStream;

public final class ResultWriter {

    private final ObjectMapper mapper;

    public ResultWriter() {
        this.mapper = JsonMapper.builder()
            .enable(SerializationFeature.INDENT_OUTPUT)
            .build();
    }

    public void write(DecisionResult result, OutputStream out) throws IOException {
        mapper.writeValue(out, result);
    }

    public String toJson(DecisionResult result) throws IOException {
        return mapper.writeValueAsString(result);
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\io\json\ResultWriter.java" $writer


# ---------- test/engine/DecisionEngineTest.java ----------
$deTest = @'
package com.minichoice.engine;

import com.minichoice.domain.*;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class DecisionEngineTest {

    private Scenario ambulance() {
        return new Scenario(
            "ambulance-v1",
            List.of(
                new Resource("A1", "ambulance", 1),
                new Resource("A2", "ambulance", 1),
                new Resource("A3", "ambulance", 1)
            ),
            List.of(
                new Candidate("P1", 5, 0.9, 4.2),
                new Candidate("P2", 4, 0.6, 2.1),
                new Candidate("P3", 5, 0.85, 6.0),
                new Candidate("P4", 2, 0.3, 1.0),
                new Candidate("P5", 3, 0.5, 3.3)
            ),
            List.of(
                new Constraint(ConstraintType.MAX_ASSIGNMENTS_PER_RESOURCE, 1, null),
                new Constraint(ConstraintType.MAX_TOTAL_ASSIGNMENTS, 3, null)
            ),
            List.of(
                new Probability("A1","P1",0.9), new Probability("A1","P2",0.8),
                new Probability("A1","P3",0.7), new Probability("A1","P4",0.95),
                new Probability("A1","P5",0.85),
                new Probability("A2","P1",0.85), new Probability("A2","P2",0.9),
                new Probability("A2","P3",0.6), new Probability("A2","P4",0.8),
                new Probability("A2","P5",0.9),
                new Probability("A3","P1",0.7), new Probability("A3","P2",0.75),
                new Probability("A3","P3",0.95), new Probability("A3","P4",0.7),
                new Probability("A3","P5",0.8)
            ),
            List.of(
                new Cost("A1","P1",10), new Cost("A2","P3",12), new Cost("A3","P3",11)
            ),
            new Objective(ObjectiveType.MAXIMIZE, new Weights(1.0, 0.5, 0.05, 1.0))
        );
    }

    @Test
    void runs_full_pipeline_and_returns_sorted_solutions() {
        var engine = new DecisionEngine();
        var result = engine.decide(ambulance());

        assertThat(result.generatedCombinations()).isGreaterThan(0);
        assertThat(result.feasibleCombinations()).isGreaterThan(0);
        assertThat(result.truncated()).isFalse();
        assertThat(result.rankedSolutions()).isNotEmpty();

        var scores = result.rankedSolutions().stream().map(Solution::score).toList();
        for (int i = 1; i < scores.size(); i++) {
            assertThat(scores.get(i)).isLessThanOrEqualTo(scores.get(i - 1));
        }

        // Top solution has explanations attached
        assertThat(result.rankedSolutions().get(0).explanation()).isNotEmpty();
    }

    @Test
    void deterministic_results_across_runs() {
        var engine = new DecisionEngine();
        var r1 = engine.decide(ambulance());
        var r2 = engine.decide(ambulance());

        assertThat(r1.rankedSolutions().size()).isEqualTo(r2.rankedSolutions().size());
        for (int i = 0; i < r1.rankedSolutions().size(); i++) {
            assertThat(r1.rankedSolutions().get(i).score())
                .isEqualTo(r2.rankedSolutions().get(i).score());
        }
    }

    @Test
    void max_total_assignments_is_respected() {
        var engine = new DecisionEngine();
        var result = engine.decide(ambulance());
        for (Solution s : result.rankedSolutions()) {
            assertThat(s.assignments().size()).isLessThanOrEqualTo(3);
        }
    }
}
'@
Save-NoBom "$root\src\test\java\com\minichoice\engine\DecisionEngineTest.java" $deTest


# ---------- test/validation/ScenarioValidatorTest.java (create folder) ----------
$valTest = @'
package com.minichoice.validation;

import com.minichoice.domain.*;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class ScenarioValidatorTest {

    private Scenario base() {
        return new Scenario(
            "s",
            List.of(new Resource("A1", "ambulance", 1)),
            List.of(new Candidate("P1", 5, 0.9, 1.0)),
            List.of(),
            List.of(new Probability("A1", "P1", 0.8)),
            List.of(new Cost("A1", "P1", 10.0)),
            new Objective(ObjectiveType.MAXIMIZE, new Weights(1,1,1,1))
        );
    }

    @Test
    void valid_scenario_passes() {
        assertThat(new ScenarioValidator().validate(base()).valid()).isTrue();
    }

    @Test
    void duplicate_resource_id_fails() {
        var s = new Scenario(
            "s",
            List.of(new Resource("A1","t",1), new Resource("A1","t",1)),
            List.of(new Candidate("P1",1,0.5,1.0)),
            List.of(), List.of(), List.of(),
            new Objective(ObjectiveType.MAXIMIZE, new Weights(1,1,1,1))
        );
        var r = new ScenarioValidator().validate(s);
        assertThat(r.valid()).isFalse();
        assertThat(r.errors()).anyMatch(e -> e.code().equals("DUPLICATE_RESOURCE"));
    }

    @Test
    void probability_with_unknown_candidate_fails() {
        var s = new Scenario(
            "s",
            List.of(new Resource("A1","t",1)),
            List.of(new Candidate("P1",1,0.5,1.0)),
            List.of(),
            List.of(new Probability("A1","PX",0.5)),
            List.of(),
            new Objective(ObjectiveType.MAXIMIZE, new Weights(1,1,1,1))
        );
        var r = new ScenarioValidator().validate(s);
        assertThat(r.valid()).isFalse();
        assertThat(r.errors()).anyMatch(e -> e.code().equals("PROB_UNKNOWN_CANDIDATE"));
    }
}
'@
Save-NoBom "$root\src\test\java\com\minichoice\validation\ScenarioValidatorTest.java" $valTest


# ---------- test/io/json/ScenarioLoaderTest.java ----------
$loaderTest = @'
package com.minichoice.io.json;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ScenarioLoaderTest {

    private static final String JSON = """
    {
      "scenarioId": "ambulance-v1",
      "resources": [
        { "id": "A1", "type": "ambulance", "capacity": 1 }
      ],
      "candidates": [
        { "id": "P1", "priority": 5, "severity": 0.9, "distance": 4.2 }
      ],
      "constraints": [
        { "type": "MAX_TOTAL_ASSIGNMENTS", "value": 1 }
      ],
      "probabilities": [
        { "resourceId": "A1", "candidateId": "P1", "success": 0.8 }
      ],
      "costs": [
        { "resourceId": "A1", "candidateId": "P1", "cost": 10 }
      ],
      "objective": {
        "type": "MAXIMIZE",
        "weights": { "benefit": 1, "risk": 0.5, "cost": 0.1, "softPenalty": 1 }
      }
    }
    """;

    @Test
    void parses_minimal_scenario() throws Exception {
        var s = new ScenarioLoader().loadFromString(JSON);
        assertThat(s.scenarioId()).isEqualTo("ambulance-v1");
        assertThat(s.resources()).hasSize(1);
        assertThat(s.candidates()).hasSize(1);
        assertThat(s.probabilities()).hasSize(1);
        assertThat(s.costs()).hasSize(1);
        assertThat(s.constraints()).hasSize(1);
    }
}
'@
Save-NoBom "$root\src\test\java\com\minichoice\io\json\ScenarioLoaderTest.java" $loaderTest

Write-Host ""
Write-Host "=== step4-decision-engine.ps1 completed ===" -ForegroundColor Green
Get-ChildItem -Recurse -File "$root\src\main\java\com\minichoice" | Select-Object FullName