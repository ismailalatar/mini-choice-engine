package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Solution;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * Sorts solutions by Score descending.
 * Deterministic tie-breaking:
 *   1) higher score first
 *   2) fewer assignments first
 *   3) lexicographic comparison of sorted assignment list
 */
public final class Ranker {

    public List<Solution> rank(List<Solution> solutions) {
        List<Solution> copy = new ArrayList<>(solutions);
        copy.sort(comparator());
        return copy;
    }

    private Comparator<Solution> comparator() {
        return (a, b) -> {
            int byScore = Double.compare(b.score(), a.score());
            if (byScore != 0) return byScore;

            int bySize = Integer.compare(a.assignments().size(), b.assignments().size());
            if (bySize != 0) return bySize;

            return lexCompare(normalized(a), normalized(b));
        };
    }

    private static List<String> normalized(Solution s) {
        List<String> list = new ArrayList<>();
        for (Assignment a : s.assignments()) {
            list.add(a.resourceId() + "->" + a.candidateId());
        }
        list.sort(String::compareTo);
        return list;
    }

    private static int lexCompare(List<String> a, List<String> b) {
        int n = Math.min(a.size(), b.size());
        for (int i = 0; i < n; i++) {
            int c = a.get(i).compareTo(b.get(i));
            if (c != 0) return c;
        }
        return Integer.compare(a.size(), b.size());
    }
}