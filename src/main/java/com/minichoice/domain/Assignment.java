package com.minichoice.domain;

public record Assignment(String resourceId, String candidateId) {
    public Assignment {
        if (resourceId == null || resourceId.isBlank()) throw new IllegalArgumentException("assignment.resourceId required");
        if (candidateId == null || candidateId.isBlank()) throw new IllegalArgumentException("assignment.candidateId required");
    }
}