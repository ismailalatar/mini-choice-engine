$ErrorActionPreference = "Stop"
$root = "D:\PROJECTS\WEB\mini-choice-engine"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Save-NoBom($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# ---------- engine/Evaluation.java ----------
$eval = @'
package com.minichoice.engine;

public record Evaluation(
    double expectedBenefit,
    double risk,
    double totalCost,
    double softPenalty,
    double score
) {}
'@
Save-NoBom "$root\src\main\java\com\minichoice\engine\Evaluation.java" $eval


# ---------- engine/Scorer.java ----------
$scorer = @'
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
'@
Save-NoBom "$root\src\main\java\com\minichoice\engine\Scorer.java" $scorer


# ---------- engine/Ranker.java ----------
$ranker = @'
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
'@
Save-NoBom "$root\src\main\java\com\minichoice\engine\Ranker.java" $ranker


# ---------- engine/Explainer.java ----------
$explainer = @'
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
'@
Save-NoBom "$root\src\main\java\com\minichoice\engine\Explainer.java" $explainer


# ---------- test/engine/ScorerTest.java ----------
$scorerTest = @'
package com.minichoice.engine;

import com.minichoice.domain.*;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

class ScorerTest {

    private Scenario simpleScenario() {
        return new Scenario(
            "s",
            List.of(new Resource("A1", "ambulance", 1)),
            List.of(
                new Candidate("P1", 5, 1.0, 1.0),
                new Candidate("P2", 1, 0.5, 1.0)
            ),
            List.of(),
            List.of(
                new Probability("A1", "P1", 0.8),
                new Probability("A1", "P2", 0.4)
            ),
            List.of(
                new Cost("A1", "P1", 10.0),
                new Cost("A1", "P2", 2.0)
            ),
            new Objective(ObjectiveType.MAXIMIZE, new Weights(1.0, 0.5, 0.1, 1.0))
        );
    }

    @Test
    void empty_assignment_yields_zero_everything() {
        var scorer = new Scorer();
        var e = scorer.evaluate(List.of(), simpleScenario());
        assertThat(e.expectedBenefit()).isEqualTo(0.0);
        assertThat(e.risk()).isEqualTo(0.0);
        assertThat(e.totalCost()).isEqualTo(0.0);
        assertThat(e.softPenalty()).isEqualTo(0.0);
        assertThat(e.score()).isEqualTo(0.0);
    }

    @Test
    void single_assignment_expected_values() {
        var scorer = new Scorer();
        var e = scorer.evaluate(List.of(new Assignment("A1", "P1")), simpleScenario());

        // P1: priority=5, max=5 -> pn=1.0; severity=1.0; p=0.8; cost=10
        // EB   = 1.0 * 1.0 * 0.8 = 0.8
        // Risk = 1.0 * 1.0 * 0.2 = 0.2
        // Cost = 10
        // Score = 1.0*0.8 - 0.5*0.2 - 0.1*10 = 0.8 - 0.1 - 1.0 = -0.3
        assertThat(e.expectedBenefit()).isCloseTo(0.8, within(1e-9));
        assertThat(e.risk()).isCloseTo(0.2, within(1e-9));
        assertThat(e.totalCost()).isCloseTo(10.0, within(1e-9));
        assertThat(e.score()).isCloseTo(-0.3, within(1e-9));
    }

    @Test
    void minimization_negates_score() {
        var scenario = new Scenario(
            "s",
            List.of(new Resource("A1", "ambulance", 1)),
            List.of(new Candidate("P1", 5, 1.0, 1.0)),
            List.of(),
            List.of(new Probability("A1", "P1", 0.8)),
            List.of(),
            new Objective(ObjectiveType.MINIMIZE, new Weights(1.0, 0.0, 0.0, 0.0))
        );
        var scorer = new Scorer();
        var e = scorer.evaluate(List.of(new Assignment("A1", "P1")), scenario);
        assertThat(e.score()).isCloseTo(-0.8, within(1e-9));
    }

    @Test
    void missing_probability_uses_default() {
        var scenario = new Scenario(
            "s",
            List.of(new Resource("A1", "ambulance", 1)),
            List.of(new Candidate("P1", 5, 1.0, 1.0)),
            List.of(),
            List.of(),
            List.of(),
            new Objective(ObjectiveType.MAXIMIZE, new Weights(1.0, 0.0, 0.0, 0.0))
        );
        var scorer = new Scorer();
        var e = scorer.evaluate(List.of(new Assignment("A1", "P1")), scenario);
        assertThat(e.expectedBenefit()).isCloseTo(0.5, within(1e-9));
    }
}
'@
Save-NoBom "$root\src\test\java\com\minichoice\engine\ScorerTest.java" $scorerTest


# ---------- test/engine/RankerTest.java ----------
$rankerTest = @'
package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Solution;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class RankerTest {

    private Solution s(double score, List<Assignment> as) {
        return new Solution(as, 0, 0, 0, 0, score, List.of());
    }

    @Test
    void sorts_by_score_desc() {
        var r = new Ranker();
        var a = s(0.5, List.of());
        var b = s(0.9, List.of());
        var c = s(0.1, List.of());
        var ranked = r.rank(List.of(a, b, c));
        assertThat(ranked.get(0).score()).isEqualTo(0.9);
        assertThat(ranked.get(1).score()).isEqualTo(0.5);
        assertThat(ranked.get(2).score()).isEqualTo(0.1);
    }

    @Test
    void tie_break_by_fewer_assignments() {
        var r = new Ranker();
        var a = s(0.5, List.of(new Assignment("A1","P1"), new Assignment("A2","P2")));
        var b = s(0.5, List.of(new Assignment("A1","P1")));
        var ranked = r.rank(List.of(a, b));
        assertThat(ranked.get(0).assignments()).hasSize(1);
        assertThat(ranked.get(1).assignments()).hasSize(2);
    }

    @Test
    void tie_break_lexicographic() {
        var r = new Ranker();
        var a = s(0.5, List.of(new Assignment("A2","P2")));
        var b = s(0.5, List.of(new Assignment("A1","P1")));
        var ranked = r.rank(List.of(a, b));
        assertThat(ranked.get(0).assignments().get(0).resourceId()).isEqualTo("A1");
    }
}
'@
Save-NoBom "$root\src\test\java\com\minichoice\engine\RankerTest.java" $rankerTest


# ---------- test/engine/ExplainerTest.java ----------
$explainerTest = @'
package com.minichoice.engine;

import com.minichoice.domain.Assignment;
import com.minichoice.domain.Solution;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class ExplainerTest {

    @Test
    void produces_lines_for_each_field() {
        var s = new Solution(
            List.of(new Assignment("A1", "P1")),
            0.8, 0.2, 10.0, 0.0, -0.3, List.of()
        );
        var lines = new Explainer().explain(s, null);
        assertThat(lines).anyMatch(l -> l.startsWith("Score="));
        assertThat(lines).anyMatch(l -> l.startsWith("ExpectedBenefit="));
        assertThat(lines).anyMatch(l -> l.contains("A1->P1"));
        assertThat(lines).anyMatch(l -> l.contains("Best solution"));
    }

    @Test
    void delta_shown_when_next_present() {
        var s1 = new Solution(List.of(), 0,0,0,0, 0.9, List.of());
        var s2 = new Solution(List.of(), 0,0,0,0, 0.5, List.of());
        var lines = new Explainer().explain(s1, s2);
        assertThat(lines).anyMatch(l -> l.contains("Advantage over next"));
    }
}
'@
Save-NoBom "$root\src\test\java\com\minichoice\engine\ExplainerTest.java" $explainerTest

Write-Host ""
Write-Host "=== step3-scorer.ps1 completed ===" -ForegroundColor Green
Get-ChildItem -File "$root\src\main\java\com\minichoice\engine" | Select-Object Name