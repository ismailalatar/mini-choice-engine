package com.minichoice.golden;

import com.minichoice.domain.Scenario;
import com.minichoice.domain.Solution;
import com.minichoice.engine.DecisionEngine;
import com.minichoice.engine.DecisionResult;
import com.minichoice.io.json.ScenarioLoader;
import com.minichoice.validation.ScenarioValidator;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * End-to-end test on the shipped ambulance example.
 * Ensures the JSON file is valid, the engine runs, and results are deterministic.
 */
class GoldenScenarioTest {

    private static final Path EXAMPLE = Path.of("examples", "ambulance.json");

    @Test
    void example_file_exists() {
        assertThat(Files.exists(EXAMPLE)).isTrue();
    }

    @Test
    void ambulance_scenario_runs_end_to_end() throws Exception {
        Scenario scenario = new ScenarioLoader().loadFromFile(EXAMPLE);
        assertThat(new ScenarioValidator().validate(scenario).valid()).isTrue();

        DecisionResult result = new DecisionEngine().decide(scenario);

        assertThat(result.generatedCombinations()).isGreaterThan(0);
        assertThat(result.feasibleCombinations()).isGreaterThan(0);
        assertThat(result.truncated()).isFalse();
        assertThat(result.rankedSolutions()).isNotEmpty();

        List<Solution> sols = result.rankedSolutions();

        // Sorted descending by score
        for (int i = 1; i < sols.size(); i++) {
            assertThat(sols.get(i).score()).isLessThanOrEqualTo(sols.get(i - 1).score());
        }

        // Top solution must have explanation attached
        assertThat(sols.get(0).explanation()).isNotEmpty();

        // Every solution must respect MAX_TOTAL_ASSIGNMENTS=3
        for (Solution s : sols) {
            assertThat(s.assignments().size()).isLessThanOrEqualTo(3);
        }
    }

    @Test
    void deterministic_across_runs() throws Exception {
        Scenario scenario = new ScenarioLoader().loadFromFile(EXAMPLE);

        DecisionResult r1 = new DecisionEngine().decide(scenario);
        DecisionResult r2 = new DecisionEngine().decide(scenario);

        assertThat(r1.rankedSolutions()).hasSameSizeAs(r2.rankedSolutions());

        for (int i = 0; i < r1.rankedSolutions().size(); i++) {
            assertThat(r1.rankedSolutions().get(i).score())
                .isEqualTo(r2.rankedSolutions().get(i).score());
        }
    }
}