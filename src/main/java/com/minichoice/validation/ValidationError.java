package com.minichoice.validation;

public record ValidationError(String code, String message) {
    @Override
    public String toString() { return code + ": " + message; }
}