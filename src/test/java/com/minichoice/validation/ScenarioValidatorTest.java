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