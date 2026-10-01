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