#Demo for Randoop and EvoSuite

Both runRandoop and runEvoSuite scripts will:

 - generate tests for the examples in the *benchmark* folder
 - run JaCoCo to evaluate **statement** and **branch** coverage (see generated *jacoco.report.resumed* for results)

#Examples

There are four examples for a *Queue* implementation based on a linked list:

 - **BadQueue**, the *dequeue* method is missing the line which decrements the queue's size, this example does not have a *repOk* method
 - **Queue**, a correct implementation with a *repOk* method annotated with *@CheckRep* for Randoop to use as invariant
 - **GoodQueue**, a correct implementation with an *inv* method with no annotations, and the invariant is incorrect
 - **GoodQueueWithRep**, a correct implementation with an incorrect *repOk* method annotated with *@CheckRep* for Randoop to use as invariant

To run each example the script (either runRandoop or runEvoSuite) must be called respectively with *bad*, *normal*, *good*, and *goodWithRep*
*note: the example's names are not really representative*.

After each run you should execute *clean.sh* to clean all generated files.

#Adding new examples

To add a new example the source files must be stored in *benchmark/src* folder and the
compiled files in *benchmark/bin* folder. And modify each script with the new example.

EvoSuite: http://www.evosuite.org 
Randoop: https://randoop.github.io/randoop/
