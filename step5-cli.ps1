$ErrorActionPreference = "Stop"
$root = "D:\PROJECTS\WEB\mini-choice-engine"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Save-NoBom($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# ---------- cli/Main.java ----------
$main = @'
package com.minichoice.cli;

import picocli.CommandLine;
import picocli.CommandLine.Command;

@Command(
    name = "minichoice",
    mixinStandardHelpOptions = true,
    version = "2.0.0",
    description = "Decision Optimization Engine — SRS v2",
    subcommands = {
        RunCommand.class,
        ValidateCommand.class
    }
)
public final class Main implements Runnable {

    @Override
    public void run() {
        CommandLine.usage(this, System.out);
    }

    public static void main(String[] args) {
        int exitCode = new CommandLine(new Main()).execute(args);
        System.exit(exitCode);
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\cli\Main.java" $main


# ---------- cli/RunCommand.java ----------
$run = @'
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
'@
Save-NoBom "$root\src\main\java\com\minichoice\cli\RunCommand.java" $run


# ---------- cli/ValidateCommand.java ----------
$validate = @'
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
            System.out.println("OK — scenario '" + scenario.scenarioId() + "' is valid.");
            return 0;
        }

        System.err.println("INVALID — " + vr.errors().size() + " error(s):");
        for (ValidationError e : vr.errors()) {
            System.err.println("  - " + e);
        }
        return 2;
    }
}
'@
Save-NoBom "$root\src\main\java\com\minichoice\cli\ValidateCommand.java" $validate


# ---------- examples/ambulance.json ----------
$json = @'
{
  "scenarioId": "ambulance-v1",
  "resources": [
    { "id": "A1", "type": "ambulance", "capacity": 1 },
    { "id": "A2", "type": "ambulance", "capacity": 1 },
    { "id": "A3", "type": "ambulance", "capacity": 1 }
  ],
  "candidates": [
    { "id": "P1", "priority": 5, "severity": 0.90, "distance": 4.2 },
    { "id": "P2", "priority": 4, "severity": 0.60, "distance": 2.1 },
    { "id": "P3", "priority": 5, "severity": 0.85, "distance": 6.0 },
    { "id": "P4", "priority": 2, "severity": 0.30, "distance": 1.0 },
    { "id": "P5", "priority": 3, "severity": 0.50, "distance": 3.3 }
  ],
  "constraints": [
    { "type": "MAX_ASSIGNMENTS_PER_RESOURCE", "value": 1 },
    { "type": "MAX_TOTAL_ASSIGNMENTS", "value": 3 }
  ],
  "probabilities": [
    { "resourceId": "A1", "candidateId": "P1", "success": 0.90 },
    { "resourceId": "A1", "candidateId": "P2", "success": 0.80 },
    { "resourceId": "A1", "candidateId": "P3", "success": 0.70 },
    { "resourceId": "A1", "candidateId": "P4", "success": 0.95 },
    { "resourceId": "A1", "candidateId": "P5", "success": 0.85 },

    { "resourceId": "A2", "candidateId": "P1", "success": 0.85 },
    { "resourceId": "A2", "candidateId": "P2", "success": 0.90 },
    { "resourceId": "A2", "candidateId": "P3", "success": 0.60 },
    { "resourceId": "A2", "candidateId": "P4", "success": 0.80 },
    { "resourceId": "A2", "candidateId": "P5", "success": 0.90 },

    { "resourceId": "A3", "candidateId": "P1", "success": 0.70 },
    { "resourceId": "A3", "candidateId": "P2", "success": 0.75 },
    { "resourceId": "A3", "candidateId": "P3", "success": 0.95 },
    { "resourceId": "A3", "candidateId": "P4", "success": 0.70 },
    { "resourceId": "A3", "candidateId": "P5", "success": 0.80 }
  ],
  "costs": [
    { "resourceId": "A1", "candidateId": "P1", "cost": 10.0 },
    { "resourceId": "A2", "candidateId": "P3", "cost": 12.0 },
    { "resourceId": "A3", "candidateId": "P3", "cost": 11.0 }
  ],
  "objective": {
    "type": "MAXIMIZE",
    "weights": { "benefit": 1.0, "risk": 0.5, "cost": 0.05, "softPenalty": 1.0 }
  }
}
'@
Save-NoBom "$root\examples\ambulance.json" $json


# ---------- test/golden/GoldenScenarioTest.java ----------
$golden = @'
package com.minichoice.golden;

import com.minichoice.domain.Scenario;
import com.minichoice.domain.Solution;
import com.minichoice.engine.DecisionEngine;
import com.minichoice.engine.DecisionResult;
import com.minichoice.io.json.ScenarioLoader;
import com.minichoice.validation.ScenarioValidator;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * End-to-end test on the shipped ambulance example.
 * Ensures the JSON file is valid, the engine runs, and results are deterministic.
 */
class GoldenScenarioTest {

    private static final Path EXAMPLE = Path.of("examples", "ambulance.json");

    @Test
    void example_file_exists() {
        assertThat(Files.exists(EXAMPLE)).isTrue();
    }

    @Test
    void ambulance_scenario_runs_end_to_end() throws Exception {
        Scenario scenario = new ScenarioLoader().loadFromFile(EXAMPLE);
        assertThat(new ScenarioValidator().validate(scenario).valid()).isTrue();

        DecisionResult result = new DecisionEngine().decide(scenario);

        assertThat(result.generatedCombinations()).isGreaterThan(0);
        assertThat(result.feasibleCombinations()).isGreaterThan(0);
        assertThat(result.truncated()).isFalse();
        assertThat(result.rankedSolutions()).isNotEmpty();

        List<Solution> sols = result.rankedSolutions();

        // Sorted descending by score
        for (int i = 1; i < sols.size(); i++) {
            assertThat(sols.get(i).score()).isLessThanOrEqualTo(sols.get(i - 1).score());
        }

        // Top solution must have explanation attached
        assertThat(sols.get(0).explanation()).isNotEmpty();

        // Every solution must respect MAX_TOTAL_ASSIGNMENTS=3
        for (Solution s : sols) {
            assertThat(s.assignments().size()).isLessThanOrEqualTo(3);
        }
    }

    @Test
    void deterministic_across_runs() throws Exception {
        Scenario scenario = new ScenarioLoader().loadFromFile(EXAMPLE);

        DecisionResult r1 = new DecisionEngine().decide(scenario);
        DecisionResult r2 = new DecisionEngine().decide(scenario);

        assertThat(r1.rankedSolutions()).hasSameSizeAs(r2.rankedSolutions());

        for (int i = 0; i < r1.rankedSolutions().size(); i++) {
            assertThat(r1.rankedSolutions().get(i).score())
                .isEqualTo(r2.rankedSolutions().get(i).score());
        }
    }
}
'@
Save-NoBom "$root\src\test\java\com\minichoice\golden\GoldenScenarioTest.java" $golden


Write-Host ""
Write-Host "=== step5-cli.ps1 completed ===" -ForegroundColor Green
Get-ChildItem -File "$root\src\main\java\com\minichoice\cli" | Select-Object Name
Get-ChildItem -File "$root\examples" | Select-Object Name
Get-ChildItem -File "$root\src\test\java\com\minichoice\golden" | Select-Object Name