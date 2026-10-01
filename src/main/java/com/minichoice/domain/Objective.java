package com.minichoice.domain;

public record Objective(ObjectiveType type, Weights weights) {
    public Objective {
        if (type == null) throw new IllegalArgumentException("objective.type required");
        if (weights == null) throw new IllegalArgumentException("objective.weights required");
    }
}