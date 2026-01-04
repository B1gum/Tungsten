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



| **Plot_001** | **Plot_002** |
| :---: | :---: |
|![sine of x times exponential of negative one fifth x](images/expsin.png)| ![cosine of x times exponential of one fifth x](images/expcos.png)|

### Implicit Equations

These are equations relating two variables (usually `x` and `y`).
They are typically used for circles, ellipses, and other curves where `y` cannot be easily isolated.

```latex
  x^2 + y^2 = 4
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_001}

  \frac{p^2}{4} + \frac{q^2}{9} = 1
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_002}
```




| **Plot_001** | **Plot_002** |
| :---: | :---: |
|![x squared plus y squared equals 4](images/xycirc.png)| ![p squared over 4 plus q squared over 9 equals 1](images/pqeli.png)|


### Inequalities

For regions defined by inequality operators (`<`, `>`, `≤`, `≥`, `\leq`, `geq`, etc.) the backend will shade the region satisfying the condition.

```latex
  y < \sin(x)
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_001}

  x \cdot y \leq 2 \cdot y
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_002}
```




| **Plot_001** | **Plot_002** |
| :---: | :---: |
|![y is less than sine of x](images/ineqsin.png)| ![x times y is less than or equal to 2 times y](images/ineqxy.png)|

*Note*: Chained inequalities such as `- \sin(x) < y < \sin(x)` are not currently supported for either backend.

### Parametric Curves

Tuples of two functions depending on a single parameter (usually `t`) are parsed as parametric curves.
The first element maps to the first axis, and the second to the second axis.

```latex
  (\cos(3t), \sin(2t))
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_001}

  (\tan(3x), \tan(4x))
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_002}


  (\sin(2y^2), 2y)
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_003}
```

| **Plot_001** | **Plot_002** | **Plot_003** |
| :---: | :---: | :---: |
|![Cosine of 3 t and sine of 2 t](images/par1.png) | ![Tangent of 3 x and tangent of 4 x](images/par2.png) | ![Sine of 2 y squared and 2 y](images/par3.png) |

*Note*: The default range of the variable of parametrization is `[-10; 10]`.

### Polar Coordinates

Expressions involving the variable `\theta` (θ) are automatically parsed as polar functions `r(θ)`.
By default, polar plots are generated with `0 < \theta < 2 \pi`.

```latex
  1 + \cos(\theta)
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_001}
```

| **Plot_001** |
| :---: |
|![1 plus cosine of t](images/polar.png) |


*Note*: For a workaround to use `\theta` in non-polar plots see the [link](#advanced-usage).

### Scatter Plots

A finite set of 2D points is parsed as a scatter plot.

```latex
  (0,0), (1,1), (2,4), (3,9)
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_001}

  (-1,1), (0,0), (1,-1), (4,-4)
  \includegraphics[width=0.8\linewidth]{tungsten_plots/plot_002}
```

| **Plot_001** | **Plot_002** |
| :---: | :---: |
|![Scatter plot 1](images/scat1.png)| ![Scatter plot 2](images/scat2.png)|



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
