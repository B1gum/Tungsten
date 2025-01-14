# Contributing to Tungsten

Thank you for considering contributing to **Tungsten**! Your contributions help make this project better for everyone. Below are guidelines to help you contribute effectively.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Requesting Features](#requesting-features)
  - [Submitting Changes](#submitting-changes)
- [Code Standards](#code-standards)
- [Style Guides](#style-guides)
- [Pull Request Process](#pull-request-process)
- [Additional Notes](#additional-notes)

## Code of Conduct

Please skim through our [Code of Conduct](CODE_OF_CONDUCT.md) to understand the standards we expect from our community members.

## How to Contribute

### Reporting Bugs

If you find a bug in **Tungsten**, please [open an issue](https://github.com/B1gum/Tungsten/issues) with the following information:

- A clear and descriptive title
- A detailed description of the problem
- Steps to reproduce the issue
- Expected and actual behavior
- Screenshots or code snippets if applicable

### Requesting Features

To suggest a new feature, please [open an issue](https://github.com/B1gum/Tungsten/issues) and include:

- A clear and descriptive title
- A detailed description of the feature
- The motivation or use case for the feature
- Optionally a syntax for the feature that you feel makes sense

### Submitting Changes

1. **Fork the Repository:**

   Click the "Fork" button at the top right of the repository page to create your own fork.

2. **Clone Your Fork:**
   
   ```bash
   git clone https://github.com/your-username/Tungsten.git
   ```
   
3. **Create a New Branch:**

   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Make Your Changes:**
   Implement your feature or bug fix. Ensure that your code adheres to the project's coding standards.

5. **Run Tests:**
   Ensure all existing and new tests pass. For now please do this by running `:TungstenRunAllTests` (default keymap is <leader>??)

6. **Commit Your Changes:**

   ```bash
   git add .
   git commit -m "Add feature: your-feature-name"
   ```

7. **Push to Your Fork:**

   ```bash
   git push origin feature/your-feature-name
   ```

8. **Submit a Pull Request:**
  Navigate to the original repository on GitHub and click "Compare & pull request." Provide a clear description of your changes and reference any related issues.


## Code Standards

- **Consistency:** Follow the existing coding style and conventions used in the project.
- **Clarity:** Write clear and understandable code with meaningful variable and function names.
- **Documentation:** Document your code where necessary, including comments and docstrings.


## Style Guides

Refer to the following style guides to maintain consistency across the project:
  - **Lua Style Guide:** https://github.com/freakboy3741/lua-style-guide
  - **Markdown Style Guide:** https://www.markdownguide.org/basic-syntax/


## Pull Request Process

1. **Ensure the PR Follows the Guidelines:**
    - The PR title should be descriptive.
    - The PR description should explain the changes and their purpose.
    - Reference any related issues using `Closes #issue-number` or `Fixes #issue-number`.

2. **Run All Tests:**
   Ensure that all tests pass and that your changes do not introduce new issues.

3. **Code Review:**
   Wait for a project maintainer to review your PR. They may request changes or provide feedback.

4. **Merge:**
   Once approved, your PR will be merged into the main branch.


## Additional Notes

  - **Stay Updated:** Keep your forked repository up to date with the main repository to avoid merge conflicts.
  - **Ask Questions:** If you're unsure about anything, feel free to [open an issue](https://github.com/B1gum/Tungsten/issues) or [reach out to the maintainers](https://github.com/B1gum.)
  - **Respect the Community:** Follow the [Code of Conduct](https://github.com/B1gum/Tungsten/blob/main/CODE_OF_CONDUCT.md) to ensure a positive and respectful environment for all contributors.
