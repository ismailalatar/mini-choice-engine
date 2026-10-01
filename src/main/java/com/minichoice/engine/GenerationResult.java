package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import java.util.List;

public record GenerationResult(List<List<Assignment>> combinations, boolean truncated) {
    public GenerationResult {
        combinations = List.copyOf(combinations);
    }
}