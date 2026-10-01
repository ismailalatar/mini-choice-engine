package com.minichoice.engine;

import com.minichoice.domain.*;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

class ScorerTest {

    private Scenario simpleScenario() {
        return new Scenario(
            "s",
            List.of(new Resource("A1", "ambulance", 1)),
            List.of(
                new Candidate("P1", 5, 1.0, 1.0),
                new Candidate("P2", 1, 0.5, 1.0)
            ),
            List.of(),
            List.of(
                new Probability("A1", "P1", 0.8),
                new Probability("A1", "P2", 0.4)
            ),
            List.of(
                new Cost("A1", "P1", 10.0),
                new Cost("A1", "P2", 2.0)
            ),
            new Objective(ObjectiveType.MAXIMIZE, new Weights(1.0, 0.5, 0.1, 1.0))
        );
    }

    @Test
    void empty_assignment_yields_zero_everything() {
        var scorer = new Scorer();
        var e = scorer.evaluate(List.of(), simpleScenario());
        assertThat(e.expectedBenefit()).isEqualTo(0.0);
        assertThat(e.risk()).isEqualTo(0.0);
        assertThat(e.totalCost()).isEqualTo(0.0);
        assertThat(e.softPenalty()).isEqualTo(0.0);
        assertThat(e.score()).isEqualTo(0.0);
    }

    @Test
    void single_assignment_expected_values() {
        var scorer = new Scorer();
        var e = scorer.evaluate(List.of(new Assignment("A1", "P1")), simpleScenario());

        // P1: priority=5, max=5 -> pn=1.0; severity=1.0; p=0.8; cost=10
        // EB   = 1.0 * 1.0 * 0.8 = 0.8
        // Risk = 1.0 * 1.0 * 0.2 = 0.2
        // Cost = 10
        // Score = 1.0*0.8 - 0.5*0.2 - 0.1*10 = 0.8 - 0.1 - 1.0 = -0.3
        assertThat(e.expectedBenefit()).isCloseTo(0.8, within(1e-9));
        assertThat(e.risk()).isCloseTo(0.2, within(1e-9));
        assertThat(e.totalCost()).isCloseTo(10.0, within(1e-9));
        assertThat(e.score()).isCloseTo(-0.3, within(1e-9));
    }

    @Test
    void minimization_negates_score() {
        var scenario = new Scenario(
            "s",
            List.of(new Resource("A1", "ambulance", 1)),
            List.of(new Candidate("P1", 5, 1.0, 1.0)),
            List.of(),
            List.of(new Probability("A1", "P1", 0.8)),
            List.of(),
            new Objective(ObjectiveType.MINIMIZE, new Weights(1.0, 0.0, 0.0, 0.0))
        );
        var scorer = new Scorer();
        var e = scorer.evaluate(List.of(new Assignment("A1", "P1")), scenario);
        assertThat(e.score()).isCloseTo(-0.8, within(1e-9));
    }

    @Test
    void missing_probability_uses_default() {
        var scenario = new Scenario(
            "s",
            List.of(new Resource("A1", "ambulance", 1)),
            List.of(new Candidate("P1", 5, 1.0, 1.0)),
            List.of(),
            List.of(),
            List.of(),
            new Objective(ObjectiveType.MAXIMIZE, new Weights(1.0, 0.0, 0.0, 0.0))
        );
        var scorer = new Scorer();
        var e = scorer.evaluate(List.of(new Assignment("A1", "P1")), scenario);
        assertThat(e.expectedBenefit()).isCloseTo(0.5, within(1e-9));
    }
}