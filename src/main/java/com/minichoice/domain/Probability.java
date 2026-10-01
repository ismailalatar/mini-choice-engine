package com.minichoice.domain;

public record Probability(String resourceId, String candidateId, double success) {
    public Probability {
        if (resourceId == null || resourceId.isBlank()) throw new IllegalArgumentException("probability.resourceId required");
        if (candidateId == null || candidateId.isBlank()) throw new IllegalArgumentException("probability.candidateId required");
        if (success < 0 || success > 1) throw new IllegalArgumentException("probability.success must be in [0,1]");
    }
}