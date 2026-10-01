package com.minichoice.io.json;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ScenarioLoaderTest {

    private static final String JSON = """
    {
      "scenarioId": "ambulance-v1",
      "resources": [
        { "id": "A1", "type": "ambulance", "capacity": 1 }
      ],
      "candidates": [
        { "id": "P1", "priority": 5, "severity": 0.9, "distance": 4.2 }
      ],
      "constraints": [
        { "type": "MAX_TOTAL_ASSIGNMENTS", "value": 1 }
      ],
      "probabilities": [
        { "resourceId": "A1", "candidateId": "P1", "success": 0.8 }
      ],
      "costs": [
        { "resourceId": "A1", "candidateId": "P1", "cost": 10 }
      ],
      "objective": {
        "type": "MAXIMIZE",
        "weights": { "benefit": 1, "risk": 0.5, "cost": 0.1, "softPenalty": 1 }
      }
    }
    """;

    @Test
    void parses_minimal_scenario() throws Exception {
        var s = new ScenarioLoader().loadFromString(JSON);
        assertThat(s.scenarioId()).isEqualTo("ambulance-v1");
        assertThat(s.resources()).hasSize(1);
        assertThat(s.candidates()).hasSize(1);
        assertThat(s.probabilities()).hasSize(1);
        assertThat(s.costs()).hasSize(1);
        assertThat(s.constraints()).hasSize(1);
    }
}