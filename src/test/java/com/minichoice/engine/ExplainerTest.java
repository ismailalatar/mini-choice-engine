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