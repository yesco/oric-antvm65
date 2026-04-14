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

## ZIP
ZIP{{1 to 10}}{{1 to 10}} => ($a, $b) out $a $b ($a * $b)
Processes streams in lockstep (parallel) rather than nested.
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
## 8. Visual Interface (The Panda Header)
Every running process has a header for control (Stop, Kill, Dup, Edit, Save) and a background color indicating state:

* Green: Running.
* White: Done / Memoized.
* Pink: Waiting / Blocked (e.g., waiting for I/O).
* Red: Raised Error. (Fatal errors kill all upward parents).

------------------------------
Next Step: Should we define the standard library for the Panda's "Basic Bamboo" or detail the Inter-Panda Communication protocol?

