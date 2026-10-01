package com.minichoice.domain;

public record Cost(String resourceId, String candidateId, double cost) {
    public Cost {
        if (resourceId == null || resourceId.isBlank()) throw new IllegalArgumentException("cost.resourceId required");
        if (candidateId == null || candidateId.isBlank()) throw new IllegalArgumentException("cost.candidateId required");
        if (cost < 0) throw new IllegalArgumentException("cost.cost must be >= 0");
    }
}