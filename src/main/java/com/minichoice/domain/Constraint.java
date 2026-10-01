package com.minichoice.domain;

public record Constraint(ConstraintType type, double value, String stringValue) {
    public Constraint {
        if (type == null) throw new IllegalArgumentException("constraint.type required");
    }

    public static Constraint of(String type, double value) {
        return new Constraint(ConstraintType.valueOf(type), value, null);
    }

    public static Constraint of(String type, String stringValue) {
        return new Constraint(ConstraintType.valueOf(type), 0, stringValue);
    }
}