![Build Status](https://img.shields.io/github/actions/workflow/status/B1gum/Tungsten/ci.yml?branch=main)
![License](https://img.shields.io/github/license/B1gum/Tungsten)
![Latest Release](https://img.shields.io/github/v/release/B1gum/Tungsten)


# Tungsten

**Tungsten** is a Neovim plugin that seamlessly integrates Wolfram functionalities directly into your editor. Includes capabilities like equation solving, plotting, partial derivatives, and more—all within Neovim.

## Table of Contents

- [Installation](#installation)
  - [Using packer.nvim](#using-packernvim)
  - [Using lazy.nvim](#using-lazynvim)
  - [Using vim-plug](#using-vim-plug)
  - [Setting up the Wolfram engine](#setting-up-the-wolfram-engine)
- [Features](#features)
- [Usage](#usage)
  - [Example: Solving an Equation](#example-solving-an-equation)
- [Roadmap](#roadmap)
  - [Ongoing](#ongoing)
  - [Q1 2025](#q1-2025)
  - [Q2 2025](#q2-2025)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)


## Installation

You can install **Tungsten** using your preferred Neovim plugin manager. Please refer to your plugin manager's documentation for specific installation instructions.


### Using packer.nvim

```lua
use 'B1gum/Tungsten'
```

### Using lazy.nvim
Add the following to your lazy.nvim setup configuration:

```lua
require('lazy').setup({
  {
    'B1gum/Tungsten',
    config = function()
      -- Plugin configuration goes here
    end
  }
})
```


### Using vim-plug
Add the following to your init.vim or init.lua:

```vim
Plug 'B1gum/Tungsten'
```

Then run `:PlugInstall` within Neovim.


### Setting Up the Wolfram Engine
**Tungsten** integrates Wolfram functionalities, which requires the Wolfram Engine and WolframScript to be installed and properly configured on your computer. The steps below outline the steps to set up the necessary components.

  1. **Download and Install the Wolfram Engine**
  
  The Wolfram Engine is available for free for developers, students, and for non-commercial use. Follow these steps to download and install it:

  a. **Download the Wolfram Engine**

  1. Visit the [Wolfram Engine page](https://www.wolfram.com/engine/).
  2. Click on *Start Download*
  3. Follow the installation-guide

  b. **Download WolframScript**

  1. WolframScript available for download [here](https://www.wolfram.com/wolframscript/).
  2. Click **Download** and follow the installation guide

  c. **Get and Activate Your Free Wolfram License**

  1. If you have just followed step **a. Download the Wolfra Engine** you should be able to click a box saying **Get Your License** (or just [click here](https://account.wolfram.com/access/wolfram-engine/free)) to be taken to a site where you can obtain your free Wolfram License
  2. Agree to Wolfram's Terms-and-services and click **Get License** (you have to have a Wolfram-account for this to be possible)
  3. To activate your license you have to open up the Wolfram-engine on your device and log in once. After this your license is activated and you are ready to use **Tungsten**

As the plugin is still in rather early development please do not hesitate to [open an issue](https://github.com/B1gum/Tungsten/issues) or [Contact B1gum](https://github.com/B1gum).


## Contributing

Contributions are welcome! Please follow these steps to contribute:

1. **Fork the Repository:** Click the "Fork" button at the top of the repository page.

2. **Clone Your Fork:**
```bash
git clone https://github.com/your-username/Tungsten.git
```    

3. **Create a New Branch:**
```bash
git checkout -b feature/YourFeatureName
```

4. **Make Your Changes:** Implement your feature or bug fix.

5. **Commit Your Changes:**
```bash
git commit -m "Add feature: YourFeatureName"
```

6. **Push to Your Fork:**
```bash
git push origin feature/YourFeatureName
```

7. **Submit a Pull Request:** Navigate to the original repository and click "Compare & pull request."


Please ensure your code follows the project's coding standards and includes appropriate tests.


## License

This project is licensed under the [MIT License](LICENSE).

## Contact

For any questions or suggestions, feel free to open an issue or contact [B1gum](https://github.com/B1gum).

