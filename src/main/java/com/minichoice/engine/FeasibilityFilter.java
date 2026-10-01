package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Candidate;
import com.minichoice.domain.Constraint;
import com.minichoice.domain.ConstraintType;
import com.minichoice.domain.Cost;
import com.minichoice.domain.Resource;
import com.minichoice.domain.Scenario;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Applies HARD constraints. If any is violated -> solution is infeasible.
 * Soft constraints are NOT handled here (they contribute to SoftPenalty in Scorer).
 */
public final class FeasibilityFilter {

    public FeasibilityResult check(List<Assignment> assignments, Scenario scenario) {
        List<String> violations = new ArrayList<>();

        Map<String, Resource> resourcesById = indexById(scenario.resources(), Resource::id);
        Map<String, Candidate> candidatesById = indexById(scenario.candidates(), Candidate::id);
        Map<String, Double> costByPair = buildCostIndex(scenario.costs());

        // counts
        Map<String, Integer> perResource = new HashMap<>();
        Map<String, Integer> perCandidate = new HashMap<>();
        double totalCost = 0.0;

        for (Assignment a : assignments) {
            Resource r = resourcesById.get(a.resourceId());
            Candidate c = candidatesById.get(a.candidateId());

            if (r == null) {
                violations.add("Unknown resourceId: " + a.resourceId());
                continue;
            }
            if (c == null) {
                violations.add("Unknown candidateId: " + a.candidateId());
                continue;
            }

            perResource.merge(r.id(), 1, Integer::sum);
            perCandidate.merge(c.id(), 1, Integer::sum);
            totalCost += costByPair.getOrDefault(key(r.id(), c.id()), 0.0);
        }

        int totalAssignments = assignments.size();

        for (Constraint c : scenario.constraints()) {
            ConstraintType t = c.type();
            switch (t) {
                case MAX_ASSIGNMENTS_PER_RESOURCE -> {
                    int max = (int) c.value();
                    perResource.forEach((rid, cnt) -> {
                        if (cnt > max)
                            violations.add("Resource " + rid + " exceeded MAX_ASSIGNMENTS_PER_RESOURCE (" + cnt + " > " + max + ")");
                    });
                }
                case MAX_ASSIGNMENTS_PER_CANDIDATE -> {
                    int max = (int) c.value();
                    perCandidate.forEach((cid, cnt) -> {
                        if (cnt > max)
                            violations.add("Candidate " + cid + " exceeded MAX_ASSIGNMENTS_PER_CANDIDATE (" + cnt + " > " + max + ")");
                    });
                }
                case MAX_TOTAL_ASSIGNMENTS -> {
                    if (totalAssignments > c.value())
                        violations.add("Total assignments exceeded MAX_TOTAL_ASSIGNMENTS (" + totalAssignments + " > " + (int) c.value() + ")");
                }
                case MIN_PRIORITY_THRESHOLD -> {
                    int min = (int) c.value();
                    for (Assignment a : assignments) {
                        Candidate cand = candidatesById.get(a.candidateId());
                        if (cand != null && cand.priority() < min)
                            violations.add("Candidate " + cand.id() + " priority " + cand.priority() + " < MIN_PRIORITY_THRESHOLD " + min);
                    }
                }
                case MAX_TOTAL_COST -> {
                    if (totalCost > c.value())
                        violations.add("Total cost " + totalCost + " > MAX_TOTAL_COST " + c.value());
                }
                case CANDIDATE_REQUIRES_RESOURCE_TYPE -> {
                    String requiredType = c.stringValue();
                    for (Assignment a : assignments) {
                        Resource r = resourcesById.get(a.resourceId());
                        if (r != null && !r.type().equals(requiredType))
                            violations.add("Candidate " + a.candidateId() + " requires resource type " + requiredType + " but got " + r.type());
                    }
                }
            }
        }

        return violations.isEmpty() ? FeasibilityResult.ok() : FeasibilityResult.fail(violations);
    }

    private static <T> Map<String, T> indexById(List<T> list, java.util.function.Function<T, String> idFn) {
        Map<String, T> map = new HashMap<>();
        for (T item : list) map.put(idFn.apply(item), item);
        return map;
    }

    private static Map<String, Double> buildCostIndex(List<Cost> costs) {
        Map<String, Double> map = new HashMap<>();
        for (Cost c : costs) map.put(key(c.resourceId(), c.candidateId()), c.cost());
        return map;
    }

    private static String key(String r, String c) { return r + "::" + c; }
}