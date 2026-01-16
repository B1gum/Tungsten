# Project Overview

## Philosophy

Tungsten aims to bring a seamless computational notebook experience directly into Neovim LaTeX-buffers.

Traditionally, performing complex mathematical operations or plotting requires context switching—moving from your text editor to a browser-based notebook (like Jupyter), a dedicated mathematical application (like Mathematica), or a REPL terminal. This leads to loss of flow-state and the constant copying of expressions back and forth between the two workflows is both cumbersome and error-prone.

Tungsten bridges this gap. It allows you to write mathematical expressions, equations, and plotting commands directly in your buffer, evaluate them in real-time, and see the results immediately alongside your code. This also eliminates the problems off the faulty and clumsy copying back and forth leading to a loss flow

## How It Works vs. REPLs

A common question is: *"How is this different from sending text to a terminal toggle or a REPL plugin?"*

Standard REPL plugins generally take a selection of text and pipe it directly to an interpreter (e.g., sending `print(1+1)` to `python`). This requires you to write valid syntax for that specific language, meaning to write LaTeX-formatted assignments and reports you have to write all expressions both in LaTeX-syntax and in the syntax of your REPL-interpreter.

Tungsten is different in that it parses your normal LaTeX-formatted code and sends a corresponding correctly-formatted query to the chosen backend.

## Backends
Tungsten is backend-agnostic. It defines what needs to be solved, not how to solve it. This allows the plugin to leverage the strengths of different computational engines based on what you have installed or what the problem requires.

Currently, Tungsten supports two primary backends:

### 1. Wolfram (Default)
Connects to the Wolfram Engine (Mathematica).
  - Mechanism: Communicates via the wolframscript CLI tool.
  - Pros: The industry standard for symbolic mathematics; handles extremely complex integrals and edge cases that might stump SymPy. By far the best-implemented backend currently. Free.
  - Cons: Requires a Wolfram Engine installation and license.

### 2. Python (Under Implementation)
Will leverage the robust open-source ecosystem of Python.
  - Libraries: Will use SymPy for symbolic mathematics (integrals, derivatives, simplifications) and NumPy/Matplotlib for numerical operations and plotting.
  - Pros: Free, open-source, easy to install, and likely already available on your machine.
  - Cons: Can be slower for extremely complex symbolic manipulations compared to Wolfram. Currently completely untested.
