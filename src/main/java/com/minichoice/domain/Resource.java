package com.minichoice.domain;

public record Resource(String id, String type, int capacity) {
    public Resource {
        if (id == null || id.isBlank()) throw new IllegalArgumentException("resource.id required");
        if (type == null || type.isBlank()) throw new IllegalArgumentException("resource.type required");
        if (capacity < 1) throw new IllegalArgumentException("resource.capacity must be >= 1");
    }
}