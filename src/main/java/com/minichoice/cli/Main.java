package com.minichoice.cli;

import picocli.CommandLine;
import picocli.CommandLine.Command;

@Command(
    name = "minichoice",
    mixinStandardHelpOptions = true,
    version = "2.0.0",
    description = "Decision Optimization Engine â€” SRS v2",
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