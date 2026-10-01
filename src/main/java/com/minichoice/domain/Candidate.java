package com.minichoice.domain;

public record Candidate(String id, int priority, double severity, double distance) {
    public Candidate {
        if (id == null || id.isBlank()) throw new IllegalArgumentException("candidate.id required");
        if (priority < 0) throw new IllegalArgumentException("candidate.priority must be >= 0");
        if (severity < 0 || severity > 1) throw new IllegalArgumentException("candidate.severity must be in [0,1]");
        if (distance < 0) throw new IllegalArgumentException("candidate.distance must be >= 0");
    }
}