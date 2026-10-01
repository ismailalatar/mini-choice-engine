package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Candidate;
import com.minichoice.domain.Resource;
import com.minichoice.domain.Scenario;

import java.util.ArrayList;
import java.util.List;

/**
 * Generates all possible assignment combinations via backtracking.
 *
 * Model (MVP):
 *  - Each resource can be assigned at most ONE candidate.
 *  - Each candidate can be assigned to at most ONE resource (enforced by backtracking).
 *  - Empty combinations are allowed (a valid "do nothing" solution).
 *
 * Complexity: O((C+1)^R) upper bound, with C=candidates, R=resources.
 * Pruned by the usedCandidates set at each level.
 */
public final class CombinationGenerator {

    public GenerationResult generate(Scenario scenario, int maxCombinations) {
        if (maxCombinations < 1) {
            throw new IllegalArgumentException("maxCombinations must be >= 1");
        }

        List<Resource> resources = scenario.resources();
        List<Candidate> candidates = scenario.candidates();

        List<List<Assignment>> result = new ArrayList<>();
        boolean[] truncated = {false};

        backtrack(resources, candidates, 0, new ArrayList<>(), new boolean[candidates.size()],
                  result, maxCombinations, truncated);

        return new GenerationResult(result, truncated[0]);
    }

    private void backtrack(List<Resource> resources,
                           List<Candidate> candidates,
                           int resourceIndex,
                           List<Assignment> current,
                           boolean[] usedCandidates,
                           List<List<Assignment>> result,
                           int maxCombinations,
                           boolean[] truncated) {
        if (truncated[0]) return;

        if (resourceIndex == resources.size()) {
            result.add(new ArrayList<>(current));
            if (result.size() >= maxCombinations) {
                truncated[0] = true;
            }
            return;
        }

        Resource resource = resources.get(resourceIndex);

        // Option 1: this resource is left idle
        backtrack(resources, candidates, resourceIndex + 1, current, usedCandidates,
                  result, maxCombinations, truncated);
        if (truncated[0]) return;

        // Option 2: this resource serves one candidate
        for (int c = 0; c < candidates.size(); c++) {
            if (usedCandidates[c]) continue;
            usedCandidates[c] = true;
            current.add(new Assignment(resource.id(), candidates.get(c).id()));

            backtrack(resources, candidates, resourceIndex + 1, current, usedCandidates,
                      result, maxCombinations, truncated);

            current.remove(current.size() - 1);
            usedCandidates[c] = false;

            if (truncated[0]) return;
        }
    }
}