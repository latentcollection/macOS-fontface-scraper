# macOS Fontface Scraper

<img src="./docs/img.png" alt="Finder window depicting output" style="width: 400px; display: block;">

An `OpenFrameworks` program that generates training data from font faces installed on your Mac.

This tool automates the process of creating a dataset from installed fonts on macOS. It renders specified glyphs from each font, saving them as individual images. This can be particularly useful for machine learning projects focused on typography, such as font classification or glyph generation tasks.

## Setup and Usage

> [!NOTE]
> The program will process fonts as specified in `Constants.h`. Adjust parameters like glyph choice, image size, and output limits there before running.

1. Prerequisites:
   - Install [OpenFrameworks](https://openframeworks.cc/download/) on your macOS system.
   - Ensure you have Xcode installed (for macOS development).

2. Project Setup:
   - Clone this repository or download the source code.
   - Open `Project.xcconfig` and set the path to your OpenFrameworks library.
   - Review and adjust the configuration in `Constants.h` as needed.

3. Building the Project:
   - Open the project in Xcode.
   - Build and run the project from within Xcode.

Alternatively, if you prefer to start from scratch:
   - Use the OpenFrameworks project generator to create a new project.
   - Replace the contents of the `src/` folder with the files from this repository.

4. Running the Program:
   - Execute the program. It will automatically process installed fonts.
   - The script will generate images for each font it processes.

5. Output:
   After successful execution, find the generated images in: `/fontfaceScraper/bin/data/`
