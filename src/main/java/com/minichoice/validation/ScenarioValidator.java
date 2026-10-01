package com.minichoice.validation;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Candidate;
import com.minichoice.domain.Cost;
import com.minichoice.domain.Probability;
import com.minichoice.domain.Resource;
import com.minichoice.domain.Scenario;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Semantic validation. Structural validation is handled by Jackson.
 * Detects:
 *  - duplicate resource / candidate ids
 *  - probabilities/costs referencing unknown ids
 *  - empty resources / candidates
 */
public final class ScenarioValidator {

    public ValidationResult validate(Scenario s) {
        List<ValidationError> errors = new ArrayList<>();

        if (s.scenarioId() == null || s.scenarioId().isBlank()) {
            errors.add(new ValidationError("SCENARIO_ID_MISSING", "scenarioId is required"));
        }

        if (s.resources().isEmpty()) {
            errors.add(new ValidationError("NO_RESOURCES", "at least one resource is required"));
        }
        if (s.candidates().isEmpty()) {
            errors.add(new ValidationError("NO_CANDIDATES", "at least one candidate is required"));
        }

        Set<String> resourceIds = new HashSet<>();
        for (Resource r : s.resources()) {
            if (!resourceIds.add(r.id())) {
                errors.add(new ValidationError("DUPLICATE_RESOURCE", "duplicate resource id: " + r.id()));
            }
        }

        Set<String> candidateIds = new HashSet<>();
        for (Candidate c : s.candidates()) {
            if (!candidateIds.add(c.id())) {
                errors.add(new ValidationError("DUPLICATE_CANDIDATE", "duplicate candidate id: " + c.id()));
            }
        }

        for (Probability p : s.probabilities()) {
            if (!resourceIds.contains(p.resourceId())) {
                errors.add(new ValidationError("PROB_UNKNOWN_RESOURCE",
                    "probability references unknown resource: " + p.resourceId()));
            }
            if (!candidateIds.contains(p.candidateId())) {
                errors.add(new ValidationError("PROB_UNKNOWN_CANDIDATE",
                    "probability references unknown candidate: " + p.candidateId()));
            }
        }

        for (Cost c : s.costs()) {
            if (!resourceIds.contains(c.resourceId())) {
                errors.add(new ValidationError("COST_UNKNOWN_RESOURCE",
                    "cost references unknown resource: " + c.resourceId()));
            }
            if (!candidateIds.contains(c.candidateId())) {
                errors.add(new ValidationError("COST_UNKNOWN_CANDIDATE",
                    "cost references unknown candidate: " + c.candidateId()));
            }
        }

        return errors.isEmpty() ? ValidationResult.ok() : ValidationResult.fail(errors);
    }
}