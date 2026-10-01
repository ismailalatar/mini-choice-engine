package com.minichoice.domain;

import java.util.List;
import java.util.Objects;

public record Scenario(
    String scenarioId,
    List<Resource> resources,
    List<Candidate> candidates,
    List<Constraint> constraints,
    List<Probability> probabilities,
    List<Cost> costs,
    Objective objective
) {
    public Scenario {
        Objects.requireNonNull(scenarioId, "scenarioId");
        resources     = List.copyOf(Objects.requireNonNullElse(resources, List.of()));
        candidates    = List.copyOf(Objects.requireNonNullElse(candidates, List.of()));
        constraints   = List.copyOf(Objects.requireNonNullElse(constraints, List.of()));
        probabilities = List.copyOf(Objects.requireNonNullElse(probabilities, List.of()));
        costs         = List.copyOf(Objects.requireNonNullElse(costs, List.of()));
        Objects.requireNonNull(objective, "objective");
    }
}