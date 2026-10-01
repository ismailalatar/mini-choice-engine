package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Solution;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Produces human-readable explanations for solutions.
 * Deterministic: numbers formatted with Locale.ROOT.
 */
public final class Explainer {

    public List<String> explain(Solution s, Solution next) {
        List<String> lines = new ArrayList<>();
        lines.add(String.format(Locale.ROOT, "Score=%.6f", s.score()));
        lines.add(String.format(Locale.ROOT, "ExpectedBenefit=%.6f", s.expectedBenefit()));
        lines.add(String.format(Locale.ROOT, "Risk=%.6f", s.risk()));
        lines.add(String.format(Locale.ROOT, "TotalCost=%.6f", s.totalCost()));
        lines.add(String.format(Locale.ROOT, "SoftPenalty=%.6f", s.softPenalty()));
        lines.add("Assignments=" + render(s.assignments()));

        if (next != null) {
            double delta = s.score() - next.score();
            lines.add(String.format(Locale.ROOT, "Advantage over next solution: %.6f", delta));
        } else {
            lines.add("Best solution (no next).");
        }
        return lines;
    }

    private static String render(List<Assignment> assignments) {
        if (assignments.isEmpty()) return "[]";
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < assignments.size(); i++) {
            if (i > 0) sb.append(", ");
            Assignment a = assignments.get(i);
            sb.append(a.resourceId()).append("->").append(a.candidateId());
        }
        sb.append("]");
        return sb.toString();
    }
}