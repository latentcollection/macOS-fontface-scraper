# MacOS Fontface Scraper

`OpenFrameworks` script that generates training data from font-faces installed on your Mac.

![Finder window depicting output](docs/img.png)

To get this running
- Make sure you have [OpenFrameworks](https://openframeworks.cc/download/) installed.
- Set the path to your OpenFrameworks lib in Project.xcconfig
- Tweak the configuration as needed in `Constants.h`

Alternatively, you can start from a fresh OF project (see projects generator), and replace the `src/` files.

After successully running the script, the outputted files will be located in:

```
/fontfaceScraper/bin/data/
```
