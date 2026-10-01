package com.minichoice.engine;

public record Evaluation(
    double expectedBenefit,
    double risk,
    double totalCost,
    double softPenalty,
    double score
) {}