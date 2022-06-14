# EvoDoop

This is a framework of scripts to easily run evosuite and randoop to generate tests, collect data from their outputs, run JaCoCo on
the generated tests, and to finally generate a csv file with all the collected data. There is also a script that allows to run a whole benchmark
with both tools.

 * EvoSuite: http://www.evosuite.org 
 * Randoop: https://randoop.github.io/randoop/
 * JaCoCo: https://github.com/jacoco/jacoco
 * EvoDoop: https://github.com/saiema/EvoDoop

# Scripts to run EvoSuite and Randoop with JaCoCo for test coverage

This repo includes a basic benchmark and several scripts. Scripts are separated between a demo usage and a more practical usage.

 * `runEvoSuiteDemo` and `runRandoopDemo` will run *EvoSuite* and *Randoop* respectively, then they will run *JaCoCo*. These will not only produce
   new tests, but will also produce a *jacoco.report.resumed* file with a simplified report on test coverage done by *JaCoCo*.

 * `clean` is a script that will clean all files produced by the test generation and coverage processes, it optionally can take a path to clean
   a specific results folder.

 * `runEvoSuite` is a script similar to `runEvoSuiteDemo` while offering a more flexible usage, use `--help` to get information about how to use it.
 
 * `runEvoSuite_configuration` is a configuration script containing only constants used by `runEvoSuite` script.
 
 * `runRandoop` **(still not available)** is the same as `runEvoSuite` but for *Randoop*.

 * `runEvoSuiteForBenchmark` is a script to run `runEvoSuite` on a whole benchmark, including several seeds for each class in the benchmark, use `--help`
   to get information about how to use it. This script will generate an csv file for the whole benchmark. While the csv file has information parsed from
   EvoSuite output, a *jacoco.report.resumed* will be generated for each run in the benchmark (a run is defined by a class, seed, and run ID).
   
 * `evosuiteLog2Csv` is an auxiliary script to parse results from *EvoSuite*'s output.

 * `runRandoopForBenchmark` **(still not available)** is the same as `runEvoSuiteForBenchmark` but for *Randoop*.

 * `utils` is an auxiliary script full of utility functions.

# Demo scripts

Both `runRandoopDemo` and `runEvoSuiteDemo` scripts will:

 - generate tests for the examples in the *benchmark* folder, specifically those in the `motivating` package.
 - run JaCoCo to evaluate **statement** and **branch** coverage (see generated *jacoco.report.resumed* for results).

# Examples

## Demo related examples (motivating package)

There are four examples for a *Queue* implementation based on a linked list:

 - **BadQueue**, the *dequeue* method is missing the line which decrements the queue's size, this example does not have a *repOk* method
 - **Queue**, a correct implementation with a *repOk* method annotated with *@CheckRep* for Randoop to use as invariant
 - **GoodQueue**, a correct implementation with an *inv* method with no annotations, and the invariant is incorrect
 - **GoodQueueWithRep**, a correct implementation with an incorrect *repOk* method annotated with *@CheckRep* for Randoop to use as invariant

To run each example the script (either `runRandoopDemo` or `runEvoSuiteDemo`) must be called respectively with *bad*, *normal*, *good*, and *goodWithRep*
*note: the example's names are not really representative*.

After each run you should execute `clean.sh` to clean all generated files. For a more specific usage, you should call `clean.sh <path to results folder>`.

### Adding new examples to the Demo scripts

To add a new example the source files must be stored in *benchmark/src* folder and the
compiled files in *benchmark/bin* folder. And modify each script with the new example.

## Non-Demo examples

There is a Stack example available.


