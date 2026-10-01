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