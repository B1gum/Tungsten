# Project Architecture Overview

## 1. Introduction
This document provides a high-level overview of the architecture of Tungsten. 

## 2. System Overview
Tungsten integrates the functionality of the WolframEngine into Neovim. The major flow of the system is:
- The user inputting a string of LaTeX-formatted text (by visually selecting and running a given command).
- The plugin parses the input and translates it to WolframScript.
- The plugin sends the parsed string to the WolframEngine.
- The result from the engine is reformatted as LaTeX and inserted into the buffer.

## 3. High-Level Structure
The repository is organized into both directories and standalone files. Each represents a logical component of the system.

### 3.1 Directories

- **`lin_alg/`**
  - **Purpose:** Contains all functionality exclusive to "linear algebra" purposes. At the moment this is mainly different matrix-operations.
  - **Key Files:**
    - `async_eval.lua`: Asynchronous-evaluation logic.
    - `operations.lua`: Contains the WolframScript for each operation one can run in the Linear algebra module.
    - `parser.lua`: Parsing functions specific to linear algebra expressions.

- **`plot/`**
  - **Purpose:** Handles plotting functionalities.
  - **Key Files:**
    - `colors.lua`: Defines colors of plotlines.
    - `command.lua`: Commands for plot generation and styling.
    - `style.lua`: Defines plotting styles.

- **`tests/`**
  - **Purpose:** Contains unit and integration tests to ensure code quality.
  - **Key Files:**  
    A variety of test files covering evaluation, parsing, solving, and other functionalities. This module is mainly for developing/debugging-purposes – It might be removed from the public interface in the future.

- **`utils/`**
  - **Purpose:** Provides utility functions used across the project.
  - **Key Files:**
    - `extractors.lua`: Functions to extract different data from the input (among others the style and range-spec of plots).
    - `io_utils.lua`: Small file only containing debug-printing logic and plot-name generation atm.
    - `string_utils.lua`: Helper functions to manipulate strings. Mainly different string-splitters right now.
    - `validation.lua`: Functions to validate inputs. At the moment only one function is contained which checks for balances braces.
    - `parser.lua`: Main parsing logic of the plugin. Is built around one major `preprocess_equation` function which does the grunt LaTeX-WolframScript conversion.

### 3.2 Root Files

The root directory contains several high-level components of the plugin:

- **`evaluate.lua`**
  - **Responsibility:** Provides functionality to evaluate expressions containing lots of different LaTeX/maths-constructs.

- **`simplify.lua`**
  - **Responsibility:** Simplifies mathematical expressions.
  - **Notes:** Contains the logic for reducing expressions to simpler forms.

- **`solve.lua`**
  - **Responsibility:** Provides functionality to solve an equation for a variable or solve a system of equations.

- **`taylor.lua`**
  - **Responsibility:** Implements Taylor series expansion functionalities.

- **Other Files:**
  - **`async.lua`** – Contains asynchronous routines for all "Root files". 
  - **`cache.lua`** – Implements caching mechanisms to improve performance – Note: This is not working as expected currently, it is unknown whether caching logic will be removed in favor of a persistent connection to the engine.
  - **`telescope.lua` & `which_key.lua`** – Provide integration points with Neovim’s plugin ecosystem – It is unknown if these will be included in the final version of the plugin or all setup at that point will be left to the end user.


## 4. Design Decisions and Rationale
- Modularity: Each module is designed to perform a specific task, enabling easy maintenance and testing.
- Separation of Concerns: The parsing, evaluation, and formatting responsibilities are separated to allow for independent development and debugging.
- Scalability: The architecture is designed to be extended with additional features (e.g., support for more formats) without significant refactoring.

## 5. Future Considerations
- Enhanced Error Handling: Introduce centralized logging and error management.
- User Customization: Allow users to configure aspects of the parsing and formatting logic.
- Performance Optimizations: Evaluate potential performance bottlenecks as the plugin scales.

Document Last Updated: 2. February 2025
