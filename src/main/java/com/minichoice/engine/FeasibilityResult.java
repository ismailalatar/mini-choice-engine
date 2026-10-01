package com.minichoice.engine;

import java.util.List;

public record FeasibilityResult(boolean feasible, List<String> violations) {
    public FeasibilityResult {
        violations = List.copyOf(violations);
    }

    public static FeasibilityResult ok() {
        return new FeasibilityResult(true, List.of());
    }

    public static FeasibilityResult fail(List<String> violations) {
        return new FeasibilityResult(false, violations);
    }
}