package com.minichoice.engine;

import com.minichoice.domain.Solution;

import java.util.List;

public record DecisionResult(
    int generatedCombinations,
    int feasibleCombinations,
    boolean truncated,
    List<Solution> rankedSolutions
) {
    public DecisionResult {
        rankedSolutions = List.copyOf(rankedSolutions);
    }
}