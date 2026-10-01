package com.minichoice.io.json;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;
import com.minichoice.domain.Scenario;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

public final class ScenarioLoader {

    private final ObjectMapper mapper;

    public ScenarioLoader() {
        this.mapper = JsonMapper.builder()
            .disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .build();
    }

    public Scenario loadFromFile(Path path) throws IOException {
        try (InputStream in = Files.newInputStream(path)) {
            return mapper.readValue(in, Scenario.class);
        }
    }

    public Scenario loadFromString(String json) throws IOException {
        return mapper.readValue(json, Scenario.class);
    }
}