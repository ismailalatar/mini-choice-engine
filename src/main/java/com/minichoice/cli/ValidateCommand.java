package com.minichoice.cli;

import com.minichoice.domain.Scenario;
import com.minichoice.io.json.ScenarioLoader;
import com.minichoice.validation.ScenarioValidator;
import com.minichoice.validation.ValidationError;
import com.minichoice.validation.ValidationResult;
import picocli.CommandLine.Command;
import picocli.CommandLine.Parameters;

import java.nio.file.Path;
import java.util.concurrent.Callable;

@Command(
    name = "validate",
    description = "Validate a scenario JSON file without running the engine."
)
public final class ValidateCommand implements Callable<Integer> {

    @Parameters(index = "0", description = "Path to scenario JSON file")
    private Path scenarioPath;

    @Override
    public Integer call() throws Exception {
        Scenario scenario = new ScenarioLoader().loadFromFile(scenarioPath);
        ValidationResult vr = new ScenarioValidator().validate(scenario);

        if (vr.valid()) {
            System.out.println("OK â€” scenario '" + scenario.scenarioId() + "' is valid.");
            return 0;
        }

        System.err.println("INVALID â€” " + vr.errors().size() + " error(s):");
        for (ValidationError e : vr.errors()) {
            System.err.println("  - " + e);
        }
        return 2;
    }
}