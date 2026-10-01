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