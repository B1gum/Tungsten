# Plotting

Tungsten's plotting domain allows you to visualize mathematical expressions directly from your editor.
By leveraging the plotting capabilities of the configured backends you are able to render high-quality 2D and 3D figures, which are then automatically inserted into your document.

This domain is designed to be "smart", in the way that it analyzes the structure of your expressions to automatically determine the most appropriate plot type (e.g. distinguishing between a 2D curve and a 3D surface).

## Basic Usage

To create a plot, visually select a mathematical expression and run `:TungstenPlot`.
Tungsten will then:
1. Parse the selection.
1. Classify the plot type
1. Render the plot using the active backend.
1. Insert the resulting \includegraphics-string with the correct path into your buffer.


## 2D Plotting Types

Tungsten supports a wide range of 2D plot types. These are all explained underneath.

### Explicit Functions

These are standard functions of one variable (e.g. `x`).
Tungsten assumes the result maps to `y` (unless the explicit variable is `y`, in which case the result is assumed to map to `x`.

```latex
  \sin(x) \cdot e^{-\frac{x}{5}}
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_001}

  \cos(y) \cdot e^{x/5}
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_002}
```
| **Plot of $\sin(x)$** | **Plot of $\cos(x)$** |
| :---: | :---: |
|![sine of x times exponential of negative one fifth x](images/expsin.png)| ![cosine of x times exponential of one fifth x](images/expcos.png)|


### Implicit Equations

### Inequalities

### Parametric Curves

### Polar Coordinates

### Scatter Plots

## 3D Plotting Types

### Explifit Surfaces

### Implicit Surfaces

### Parametric Surfaces and Curves

### 3D Scatter

## Multi-Series Plots

## Advanced Usage

### Global Settings

### Range-Settings

### Series Settings

## Variable Resolution

### Persistent Variables

### The Definition Window

## Output and File Management

### Directory structure

### Filename Generation

### Image Format

## Backend Comparison
