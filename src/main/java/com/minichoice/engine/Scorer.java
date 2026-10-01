package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Candidate;
import com.minichoice.domain.Cost;
import com.minichoice.domain.Objective;
import com.minichoice.domain.ObjectiveType;
import com.minichoice.domain.Probability;
import com.minichoice.domain.Scenario;
import com.minichoice.domain.Weights;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Evaluates a feasible solution and computes a single Score.
 *
 * Model:
 *   priorityNorm(c) = c.priority / maxPriority(scenario)
 *   ExpectedBenefit = SUM over assignments: priorityNorm * severity * p
 *   Risk            = SUM over assignments: priorityNorm * severity * (1 - p)
 *   TotalCost       = SUM over assignments: cost(r,c)   (default 0 if missing)
 *   SoftPenalty     = SUM of soft violations            (currently 0; reserved)
 *
 *   Score = w.benefit * ExpectedBenefit
 *         - w.risk    * Risk
 *         - w.cost    * TotalCost
 *         - w.softPenalty * SoftPenalty
 *
 * For ObjectiveType.MINIMIZE the score is negated after computation,
 * so the Ranker can always sort descending.
 *
 * Missing probability -> default 0.5 (neutral).
 * Missing cost        -> default 0.0.
 */
public final class Scorer {

    public static final double DEFAULT_PROBABILITY = 0.5;

    public Evaluation evaluate(List<Assignment> assignments, Scenario scenario) {
        Map<String, Candidate> candidatesById = new HashMap<>();
        for (Candidate c : scenario.candidates()) candidatesById.put(c.id(), c);

        Map<String, Double> probByPair = new HashMap<>();
        for (Probability p : scenario.probabilities()) {
            probByPair.put(key(p.resourceId(), p.candidateId()), p.success());
        }

        Map<String, Double> costByPair = new HashMap<>();
        for (Cost c : scenario.costs()) {
            costByPair.put(key(c.resourceId(), c.candidateId()), c.cost());
        }

        int maxPriority = scenario.candidates().stream()
            .mapToInt(Candidate::priority)
            .max()
            .orElse(1);
        if (maxPriority <= 0) maxPriority = 1;

        double eb = 0.0;
        double risk = 0.0;
        double totalCost = 0.0;

        for (Assignment a : assignments) {
            Candidate c = candidatesById.get(a.candidateId());
            if (c == null) continue;

            double pn = (double) c.priority() / maxPriority;
            double p = probByPair.getOrDefault(key(a.resourceId(), a.candidateId()), DEFAULT_PROBABILITY);
            double cost = costByPair.getOrDefault(key(a.resourceId(), a.candidateId()), 0.0);

            eb += pn * c.severity() * p;
            risk += pn * c.severity() * (1.0 - p);
            totalCost += cost;
        }

        double softPenalty = 0.0;

        Objective obj = scenario.objective();
        Weights w = obj.weights();

        double score = w.benefit() * eb
                     - w.risk() * risk
                     - w.cost() * totalCost
                     - w.softPenalty() * softPenalty;

        if (obj.type() == ObjectiveType.MINIMIZE) {
            score = -score;
        }

        return new Evaluation(eb, risk, totalCost, softPenalty, score);
    }

    private static String key(String r, String c) { return r + "::" + c; }
}