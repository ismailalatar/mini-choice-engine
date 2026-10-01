package com.minichoice.cli;

import com.minichoice.domain.Scenario;
import com.minichoice.domain.Solution;
import com.minichoice.engine.DecisionEngine;
import com.minichoice.engine.DecisionResult;
import com.minichoice.io.json.ResultWriter;
import com.minichoice.io.json.ScenarioLoader;
import com.minichoice.validation.ScenarioValidator;
import com.minichoice.validation.ValidationError;
import com.minichoice.validation.ValidationResult;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import picocli.CommandLine.Parameters;

import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.Callable;

@Command(
    name = "run",
    description = "Load a scenario, run the engine, and print the top solutions."
)
public final class RunCommand implements Callable<Integer> {

    @Parameters(index = "0", description = "Path to scenario JSON file")
    private Path scenarioPath;

    @Option(names = {"-n", "--top"}, defaultValue = "5",
            description = "Number of top solutions to display (default: 5)")
    private int topN;

    @Option(names = {"-o", "--out"},
            description = "Optional path to write full results JSON")
    private Path outPath;

    @Override
    public Integer call() throws Exception {
        Scenario scenario = new ScenarioLoader().loadFromFile(scenarioPath);

        ValidationResult vr = new ScenarioValidator().validate(scenario);
        if (!vr.valid()) {
            System.err.println("Scenario is invalid:");
            for (ValidationError e : vr.errors()) {
                System.err.println("  - " + e);
            }
            return 2;
        }

        DecisionResult result = new DecisionEngine().decide(scenario);

        System.out.println("Scenario: " + scenario.scenarioId());
        System.out.println("Generated combinations: " + result.generatedCombinations());
        System.out.println("Feasible solutions:    " + result.feasibleCombinations());
        System.out.println("Truncated:             " + result.truncated());
        System.out.println();

        List<Solution> sols = result.rankedSolutions();
        int n = Math.min(topN, sols.size());
        for (int i = 0; i < n; i++) {
            Solution s = sols.get(i);
            System.out.printf(Locale.ROOT, "Solution #%d%n", i + 1);
            for (String line : s.explanation()) {
                System.out.println("  " + line);
            }
            System.out.println();
        }

        if (outPath != null) {
            try (OutputStream out = Files.newOutputStream(outPath)) {
                new ResultWriter().write(result, out);
            }
            System.out.println("Full results written to: " + outPath.toAbsolutePath());
        }

        return 0;
    }
}