package com.minichoice.validation;

import java.util.List;

public record ValidationResult(boolean valid, List<ValidationError> errors) {
    public ValidationResult {
        errors = List.copyOf(errors);
    }

    public static ValidationResult ok() { return new ValidationResult(true, List.of()); }
    public static ValidationResult fail(List<ValidationError> errors) {
        return new ValidationResult(false, errors);
    }
}