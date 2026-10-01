package com.minichoice.domain;

import java.util.List;

public record Solution(
    List<Assignment> assignments,
    double expectedBenefit,
    double risk,
    double totalCost,
    double softPenalty,
    double score,
    List<String> explanation
) {
    public Solution {
        assignments = List.copyOf(assignments);
        explanation = List.copyOf(explanation);
    }
}