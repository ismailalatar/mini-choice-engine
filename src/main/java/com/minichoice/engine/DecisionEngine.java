package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Scenario;
import com.minichoice.domain.Solution;

import java.util.ArrayList;
import java.util.List;

/**
 * Orchestrates the full pipeline:
 *   generate -> feasibility filter -> score -> rank -> explain
 *
 * Deterministic: no randomness, stable ordering.
 */
public final class DecisionEngine {

    public static final int DEFAULT_MAX_COMBINATIONS = 1_000_000;

    private final CombinationGenerator generator;
    private final FeasibilityFilter filter;
    private final Scorer scorer;
    private final Ranker ranker;
    private final Explainer explainer;
    private final int maxCombinations;

    public DecisionEngine() {
        this(DEFAULT_MAX_COMBINATIONS);
    }

    public DecisionEngine(int maxCombinations) {
        this.generator = new CombinationGenerator();
        this.filter = new FeasibilityFilter();
        this.scorer = new Scorer();
        this.ranker = new Ranker();
        this.explainer = new Explainer();
        this.maxCombinations = maxCombinations;
    }

    public DecisionResult decide(Scenario scenario) {
        GenerationResult gen = generator.generate(scenario, maxCombinations);

        List<Solution> solutions = new ArrayList<>();
        for (List<Assignment> combo : gen.combinations()) {
            FeasibilityResult fr = filter.check(combo, scenario);
            if (!fr.feasible()) continue;

            Evaluation ev = scorer.evaluate(combo, scenario);
            Solution s = new Solution(
                combo,
                ev.expectedBenefit(),
                ev.risk(),
                ev.totalCost(),
                ev.softPenalty(),
                ev.score(),
                List.of()
            );
            solutions.add(s);
        }

        List<Solution> ranked = ranker.rank(solutions);

        // attach explanations
        List<Solution> withExplanations = new ArrayList<>(ranked.size());
        for (int i = 0; i < ranked.size(); i++) {
            Solution cur = ranked.get(i);
            Solution next = (i + 1 < ranked.size()) ? ranked.get(i + 1) : null;
            List<String> explanation = explainer.explain(cur, next);
            withExplanations.add(new Solution(
                cur.assignments(),
                cur.expectedBenefit(),
                cur.risk(),
                cur.totalCost(),
                cur.softPenalty(),
                cur.score(),
                explanation
            ));
        }

        return new DecisionResult(
            gen.combinations().size(),
            withExplanations.size(),
            gen.truncated(),
            withExplanations
        );
    }
}