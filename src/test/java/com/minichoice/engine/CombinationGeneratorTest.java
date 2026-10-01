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