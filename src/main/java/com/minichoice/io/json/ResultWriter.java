package com.minichoice.io.json;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.json.JsonMapper;
import com.minichoice.engine.DecisionResult;

import java.io.IOException;
import java.io.OutputStream;

public final class ResultWriter {

    private final ObjectMapper mapper;

    public ResultWriter() {
        this.mapper = JsonMapper.builder()
            .enable(SerializationFeature.INDENT_OUTPUT)
            .build();
    }

    public void write(DecisionResult result, OutputStream out) throws IOException {
        mapper.writeValue(out, result);
    }

    public String toJson(DecisionResult result) throws IOException {
        return mapper.writeValueAsString(result);
    }
}