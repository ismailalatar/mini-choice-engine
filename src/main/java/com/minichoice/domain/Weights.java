package com.minichoice.domain;

public record Weights(double benefit, double risk, double cost, double softPenalty) {
    public Weights {
        if (benefit < 0 || risk < 0 || cost < 0 || softPenalty < 0)
            throw new IllegalArgumentException("weights must be >= 0");
    }
}