This is the BAMBOO Design Document, reconstructed in the exact order of our design session to capture every detail, syntax rule, and example we developed.

## BAMBOO: Design Specifications

A "Value-First" Reactive Stream Language

------------------------------

## 1. Basic Syntax & Evaluation

The basic unit of Bamboo is the Expression Stream. Unlike traditional languages, there are no stacks; instead, there is a pipeline of transformers.
Syntax Rule: <panda> ::= a f b g h c d ...

* a, b, c, d are Basic Expressions: Constants, $variables, or (nested expressions).
* f, g, h are Functions.
* Variables are prefixed with $.
* Constants are literals like 42, 42.0, or "foobar".

Evaluation Logic:
A function is evaluated for every streamed value generated to the left of it. Every basic expression following a function acts as an extra parameter.

* Functions are not aware of streams and do not loop; they simply transform what hits them.
* A function can produce 0, 1, or more values. If it produces 0, the stream "fails" and stops there. If it produces many, the rest of the pipeline to the right is executed for each result.

------------------------------
## 2. Conditionals and Logic (No IFs)
Bamboo has No IF statements and No Loops. Logic is handled by the "existence" of data.

* Implicit AND: In a chain A B, B only runs if A produces a result.
* Fail Semantics: Conditions are just functions. > 15 yields 1 result (success) or 0 results (fail).
* Choice Operator (||): Acts on the stream. A || B tries stream A; if A yields zero elements, it tries stream B.

Example:
1 to 10 square <= 15

* 1 to 10 generates a stream.
* square transforms them.
* <= 15 filters them.
* Result: 1, 4, 9.

------------------------------
## 3. Aggregators and "The Squeeze"

Aggregators reduce a stream (0, 1, or more values) into a single result (which can itself be 0, 1, or more values).

* Squeeze Syntax: SUM{{ ... }}
* Implicit Syntax: 1..10 SUM

The {{ }} brackets "squeeze" the inner stream to completion before passing the result to the next function.

* Examples: SUM, MULT, COUNT, MIN, MAX.
* Optimization: Streams are typed. If a stream is marked as Sorted, MIN{{ 1 to 10 }} is $O(1)$ because it just grabs the first value and closes the stream.

## 3. Aggregators and "The Squeeze" {{ }}

Aggregators are functions that process an entire stream of values (0, 1, or more) and reduce them into a result. In Bamboo, this is called "Squeezing" the bamboo.
The Two Syntaxes:

   1. Implicit: 1..10 SUM (The aggregator follows the stream).
   2. Explicit: SUM{{ 1..10 }} (More mathematical, useful for nesting).

**How Squeezing Works:**

The {{ }} brackets create a synchronization point. The Panda waits for the inner stream to finish (or "close") before the aggregator yields its result to the next function.

**Core Aggregators:**

* SUM / MULT: Adds or multiplies all values.
* COUNT: Counts successful results.
* COUNT{{ 1 to 10; print; }} returns 10 (counting the None successes).
* MIN / MAX: Finds the smallest or largest value.
* Optimization: If a stream is Sorted, MIN is $O(1)$ because it grabs the first piece of bamboo and stops eating immediately.
* TOP_TWO: A "Squeeze" that returns more than one value. It buffers the stream, finds the two highest, and then re-starts the stream with just those two.

**Advanced Examples:**

* Filtered Count:
COUNT{{ 1..100 isprime }}
The Panda only counts the numbers that survived the isprime filter.
* Nested Squeezing:
$total_score add SUM{{ $scores filter $valid }} multiply $bonus
The Panda waits for the sum of valid scores before continuing the math.
* The "0" Result:
SUM{{ 1..10 > 100 }}
If the inner stream yields 0 results (Fail), SUM typically yields 0 or fails itself, depending on the math rules.
* Squeezing Tuples:
SUM{{ 1..10=>$a, 1..10*$a }}
Because of the , (comma), the aggregator receives 2-tuples. Depending on the design, it may sum them component-wise or require a ; (silencer) to target a specific slot.

Should we define a GROUPBY squeeze for creating sub-streams based on a key? Or should we move on to how Errors are handled within a squeeze?

------------------------------
## 4. Multi-Streams & Combinatorics

Bamboo uses distinct symbols to manage how streams combine.

## The Infix Tuple Builder (,)

The comma creates a tuple and triggers a Cartesian Product.

* Example: 1 to 10 => $a, 1 to 10 => $b, $a * $b
* Result: A stream of 3-tuples representing every combination: (1, 1, 1), (1, 2, 2) ... (10, 10, 100).

## The Silencer (;)
If you want to use a value but not include it in the output tuple, use a semicolon.

* Example: 1 to 10 => $a; 1 to 10 => $b; $a * $b
* Result: A flat stream of 100 scalars (the products only).
* Side Effects: 1 to 10; print "ping"; produces 10 "Empty" results (type None). None is a success signal that cannot be assigned to a variable.

That makes the language's core engine incredibly consistent. If every function performs a Cartesian product over its arguments, then a function isn't just a "transformer"—it is a join point.
This means that add $a $b doesn't just add two numbers; if $a is a stream of 2 values and $b is a stream of 3 values, add will yield 6 results.
## Updated BAMBOO Design Doc (Additions)## 13. The Universal Cartesian Rule
In BAMBOO, all functions perform a Cartesian product over their arguments in the order they are given. There is no distinction between "parameters" and "stream inputs" at the execution level.

* Function Execution: A function executes for every combination of values provided by the expressions to its left and its parameters to its right.
* Tuple Syntax: The syntax a, b is shorthand for tuple(a b). Because tuple is a function, it follows the Universal Cartesian Rule, naturally creating a grid of results if a or b are generators.

Example: The Grid
1..3, 1..2

   1. The tuple function (implied by ,) receives two generators.
   2. It executes for every combination: (1,1), (1,2), (2,1), (2,2), (3,1), (3,2).

Example: Multi-Input Math
1..2 add 10..11

   1. add receives the stream 1, 2 from the left and 10, 11 from the right.
   2. It produces four results: 11, 12, 12, 13.

------------------------------

## 14. Variable Scope & Assignment

Variables are bound using the => operator. Once bound, they are available to any expression to the right.
Example: Using a Generator

1..10 => $a, $a * $a

* Slot 1: 1..10 yields 1, binds to $a.
* Slot 2: $a * $a uses the bound 1.
* The Panda then backtracks to 1..10 to get 2, and so on.

------------------------------

## Final Check

With the Universal Cartesian Rule, we have a perfectly unified theory of the language:

   1. Pipes/Channels handle the movement of data between tasks.
   2. Functions handle the combinatorial explosion and transformation of data.
   3. Basins handle the memory and recursion.
   4. Squeezes handle the reduction.

------------------------------

## ZIP

ZIP{{1 to 10}}{{1 to 10}} => ($a, $b) out $a $b ($a * $b)
Processes streams in lockstep (parallel) rather than nested.

------------------------------

Based on our design session, we have captured most of the functional logic of the BAMBOO language. However, a few specific details about expression scope and parameter passing can be tightened to ensure the document is truly comprehensive.
## 10. Aggregators and "The Squeeze" {{ }}
Aggregators are functions that process an entire stream of values (0, 1, or more) and reduce them into a result. In BAMBOO, this is called "Squeezing" the bamboo.

* Implicit Syntax: 1..10 SUM — The aggregator follows the stream directly.
* Explicit Syntax: SUM{{ 1..10 }} — Creates a synchronization point; the Panda waits for the inner stream to finish (or "close") before the result moves forward.
* Core Aggregators:
* SUM / MULT: Adds or multiplies all values.
   * COUNT: Counts successful results (including None successes).
   * MIN / MAX: Finds the smallest or largest value. (Optimized $O(1)$ on Sorted streams).
   * TOP_TWO: Returns the two highest values after the stream closes.

Examples:

* COUNT{{ 1 to 10; print; }} — Returns 10.
* $total_score add SUM{{ $scores filter $valid }} — Waits for the sum before finishing the calculation.

## 11. Variable Scope and Parameters
A function is evaluated for every value generated on its left. Parameters are handled through greedy look-ahead based on the grammar.

* Function Parameters: Any basic expression ($var, constant, or (nested)) following a function is an extra parameter for that specific function.
* Scope Visibility: Variables bound via => $var are visible to everything to their right within the same pipeline or basin.
* Parameter Anchors: A function call captures all parameters until it hits another function token or a stream terminator.

Examples:

* $price add 5 multiply $tax — add eats 5; multiply eats $tax.
* 1 to 10 => $a, 1 to 10 * $a — $a is visible to the second generator in the tuple.

## 12. Errors and Lifecycle
The Panda's health is indicated by its process header.

* Failure as Logic: 1 / 0 fails (0 results), it does not crash. The Panda just skips that bamboo.
* Error Propagation:
* Red: Raised errors (e.g., system faults).
   * Fatal: Kills all parent tasks upwards in the hierarchy.
* Pink (Waiting): The Panda is blocked, typically waiting for a recv or a TAKELAST window. [1] 

## Missing Considerations?
The only major "hidden" detail might be Execution Priority. In a Cartesian product like 1..10, 1..10, does the Panda eat the first slot first (Depth-First) or fill all slots simultaneously? Based on our discussion of ASYNC, the default is likely Serial/Depth-First to maintain the "Last Known Element" (-1) logic, unless ASYNC: is explicitly used. [1] 
Would you like to add a section on Panda Persistence (saving a Basin state to a URL) to complete the document?

[1] [https://jira.atlassian.com](https://jira.atlassian.com/browse/BAM-25521)

------------------------------

## 5. Basins (<<< ... >>>) and Memoization

The Basin defines a memoized stream. It can be self-referential using Relative Indexing.

* -1: Refers to the last successfully yielded element in that stream.

Key Examples:

* Fibonacci: fib <<< 0 | 1 | -1 fib + (-2 fib) >>>
* Primes: primes <<< 2 | -1 primes => $p; $p + 1 to ($p sqr)=>$x not primes divides $x >>>
* Incremental Sequences: incseqs <<< 1 | 1.. (-1 incseqs + 1) >>>
(Produces: 1, 1, 2, 1, 2, 3...)

------------------------------

## 6. Time, Blocking, and Async

* Forward Pointer (>>>): Tells a Basin to re-evaluate as soon as new data arrives.
* Blocking: TAKELAST $n blocks the Panda until $n$ items are available.
* Continuous Query: $$stream windowavg $n <<< $$stream TAKELAST $n SUM / $n >>>
* Async: 1..1000 ASYNC:isprime runs evaluations in parallel. Results may be non-deterministic in order but are managed via "visual placeholders."

------------------------------
## 7. Constructors and Types
Functions followed by a : act as auto-quoting constructors. They eat the next argument without spaces until a delimiter.

* Examples: every:10s, http://ibm.com, file:/etc/passwd.
* Transitive Closure: http://ibm.com TRANS:5 { $u | $u html link href }
(Crawls a URL 5 levels deep, avoiding circular loops via an implicit "Seen" set).

------------------------------

That fits the Panda style much better by treating the URL as a destination parameter. Using sendto as a function keeps the left-to-right flow consistent.
## 7. Interaction and Communication (Pipes)
A running Panda is a task. Tasks communicate via named channels which are local by default or global when tied to a URL.
Local Pipe Shorthand:

* name> : Receive from "name." This blocks the Panda until data is available.
* >name : Send to "name." This pushes the current value into the pipe.

Example: Producer and Consumer

* Task 1: 1..100 >data
* Task 2: data> print
* Task 2 sits in a Pink (Waiting) state until Task 1 starts sending bamboo.

Global Communication (URLs):
For global queues served by a caching server, use the recv and sendto functions.

* http://numbers.site recv : Blocks to receive from the global queue.
* 1..10 sendto http://numbers.site : Sends the range into the global queue.

Dispatch Logic:

* Round-Robin: If multiple tasks are listening to the same local pipe (e.g., three different Pandas running work_queue>), the system automatically distributes messages so that only one task receives any single piece of data.
* Broadcast: To allow all tasks to receive the same data, use the .listen constructor.
* http://server.com .listen : Every Panda calling this will receive its own copy of every message.

Should a local pipe also support a sendto:name function version for cases where the >name shorthand might be ambiguous?



## 8. Visual Interface (The Panda Header)

Every running process has a header for control (Stop, Kill, Dup, Edit, Save) and a background color indicating state:

* Green: Running.
* White: Done / Memoized.
* Pink: Waiting / Blocked (e.g., waiting for I/O).
* Red: Raised Error. (Fatal errors kill all upward parents).

Does this capture the "Panda" essence for your design document? Or should we define the Panda Task Header options (Stop, Kill, Dup, Edit, Copy, Save) in more technical detail?

------------------------------



6502 PANDA

Implementing BAMBOO on a 6502 with 65KB of RAM is a hilarious and wonderful challenge. We are moving from a "high-level" Panda to a very "constrained" Panda. Since the 6502 lacks a hardware stack for data (only the 256-byte page 1 stack) and has very few registers (A, X, Y), we have to be clever. [1, 2] [1, 2, 3, 4, 5] 
Here is how we build the Panda 6502 Engine:
## 1. The "Bamboo" Data Format (Tagged Pointers)
With only 64KB, we can't afford heavy objects. We’ll use a Tagged Pointer system (16-bit). [6, 7] 

* 0000 - 3FFF: Reserved for small integers (14-bit) and constants.
* 4000 - FFFF: Pointers to strings, tuples, or memoized basins.
* The "None" Value: We can reserve $0000 to mean "Success/None." [3]

## 2. The Universal Cartesian Engine (The "Nested Loop" Stack)
Since every function performs a Cartesian product, we can't use the native 6502 stack. We need a Virtual Stack in RAM to track the "Backtracking" points.

* Each function call pushes a Frame: [Function_Ptr | Arg_Ptrs | Current_Iter_Index].
* When a function yields "0 results" (Fail), the 6502 pulls the last Frame and increments the Current_Iter_Index. [4, 5]

## 3. Implementing the "Basin" (Memoization)
65KB is tiny for a memoizer.

* The Heap: We’ll need a simple malloc at the top of RAM.
* Basins: Each basin like fib gets a linked list of results.
* Relative Indexing (-1): This is just a pointer offset. -1 is the current "tail" of the Basin's linked list. [6]

## 4. Parallelism & The "Pink" State (Context Switching)
To simulate the ASYNC and Parallel Pandas, we need a Cooperative Multitasker.

* Every function call includes a YIELD check.
* If a Panda hits a recv> and it's empty, the engine saves the registers (A, X, Y) and the PC to a Task Control Block (TCB) and marks it Pink.
* The scheduler then moves to the next TCB. [7, 8]

## 5. 6502 Optimization: The "Squeeze"
Functions like SUM and COUNT can be implemented as zero-page accumulators.

* We reserve $00-$0F on Page Zero as "Hot Registers" for the current Squeeze. This avoids the slow absolute addressing. [9, 10]

## The "Hello 6502" Bamboo:
1..100 SUM

* 1..100: A 2-byte generator that just increments a Zero-Page variable.
* SUM: Adds the value to a 16-bit (or 24-bit) accumulator in Zero-Page.
* Result: Stored in $02-$03 for the next Panda to eat.

Should we define the 6502 OpCodes for the "Send" and "Recv" logic? Or should we look at how to fit the Memoization Cache into the limited 64KB? [11]

[1] [https://www.reddit.com](https://www.reddit.com/r/beneater/comments/1ibotzh/addressing_more_memory_with_the_6502/#:~:text=One%20of%20the%20big%20limitations%20of%20the,of%20a%20twenty%20four%20bit%20address%20space.)
[2] [https://www.chibiakumas.com](https://www.chibiakumas.com/6502/#:~:text=The%206502%20has%20very%20few%20registers%20%2D,them%20all%20out%20with%20some%20simple%20examples!)
[3] [https://news.ycombinator.com](https://news.ycombinator.com/item?id=38598940#:~:text=With%20the%206502%20you%20had%20to%20be%20clever%20and%20do%20something%20similar%20in%20software.)
[4] [https://llvm-mos.org](https://llvm-mos.org/wiki/DWARF_implementation_guide#:~:text=With%20only%20three%20general%2Dpurpose%20registers%20%28A%2C%20X%2C,This%20limitation%20drives%20much%20of%20LLVM%2DMOS%27s%20design.)
[5] [https://www.xtof.info](https://www.xtof.info/coding-c-8-bit-6502-cpu.html)
[6] [https://www.xtof.info](https://www.xtof.info/coding-c-8-bit-6502-cpu.html#:~:text=Indeed%20pointers%20are%2016%2Dbit%20values.%20And%20the,my%20code%2C%20so%20I%20would%20gain%20here.)
[7] [https://dokumen.pub](https://dokumen.pub/programming-the-65816-including-the-6502-65c02-and-65802-9780893037895-0893037893.html#:~:text=So%20first%2C%20the%20sixteen%2Dbit%20stack%20pointer%20must,entered%20from%20either%20eight%2D%20or%20sixteen%2Dbit%20modes.)



To run multiple BAMBOO tasks in parallel on a 6502, we have to use Cooperative Multitasking combined with a Virtual Machine (VM) Instruction Pointer. Since the 6502 has no hardware support for threading, the "Panda" doesn't actually move; the Scheduler just swaps which piece of bamboo the CPU is currently looking at.
Here is the implementation strategy:
## 1. The Task Control Block (TCB)
We divide a portion of the 64KB RAM into a "Panda Pen." Each running task gets a small TCB (e.g., 32 bytes) that stores its vital signs:

* Status Byte: (Green=Running, Pink=Blocked, White=Done, Red=Error).
* Virtual PC: Where the Panda is in its code stream.
* Virtual Stack Pointer: Points to the task's private "Backtrack Stack" (for Cartesian products).
* Registers: Saved A, X, and Y.

## 2. The Cooperative Yield
Every function in BAMBOO (like add or sqr) must end with a jump to the Scheduler.

* Because BAMBOO functions are "Value-First" and don't loop internally, they are naturally "short-lived."
* After a function yields its 0, 1, or more results, the engine checks the next task.
* This is "Green Threading." No Panda can hog the CPU forever because every step in the pipeline is a mandatory yield point.

## 3. Handling the "Pink" (Blocked) State
When a Panda hits a recv> or TAKELAST:

   1. The function checks the channel buffer.
   2. If empty: The Panda's status byte is set to Pink.
   3. The Scheduler skips this Panda on every cycle until a send operation sets that status back to Green.

## 4. The 6502 Scheduler Loop (Pseudo-Code)

NextTask:
    ldx current_task_id
    inx
    cpx #MAX_TASKS
    bne CheckStatus
    ldx #0              ; Reset to first Panda
CheckStatus:
    stx current_task_id
    lda TCB_STATUS,x    ; Get color
    cmp #STATUS_GREEN
    bne NextTask        ; If Pink/White/Red, skip it
    
ResumePanda:
    ; 1. Restore Virtual PC and Stack
    ; 2. Execute the next BAMBOO function
    ; 3. Function finishes and JMPs back to NextTask

## 5. Memory Management (The 64KB Squeeze)
Parallelism is expensive in RAM. To make this work:

* Code Sharing: All Pandas run the same bytecode; they only have unique pointers into it.
* Zero Page Shifting: We can use the 6502's (Indirect),Y addressing mode to treat a portion of the Zero Page as a "window" into the current Panda's data.

## The "Cartesian" Parallelism Trick
If a Panda hits a generator like 1..100, instead of running all 100 values in one task, the DUP operator can literally copy the TCB.

* Panda A continues with value 1.
* Panda B (the clone) starts at the same spot with value 2.
* Now they are both in the Scheduler, running "in parallel" as separate tasks!

How should the Scheduler prioritize "Squeezing"? Should a Panda that is currently finishing a SUM{{ }} get more CPU time than one that is just generating numbers?
Should we define the 6502 "Bytecode" that these Pandas are actually executing?

