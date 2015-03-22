# Ruby ASCIImage tools

This project includes an ASCIImage parser in Ruby, and a script
that uses the parser to convert ASCIImages to SVG.

## ASCIImage

The ASCIImage format has been [developed][airef] as an alternative, simple
way to create small icons on iOS and OS X using NSStrings. The original code
can be found [here][].

[airef]: http://cocoamine.net/blog/2015/03/20/replacing-photoshop-with-nsstring/
[here]: https://github.com/cparnot/ASCIImage

### Principles

The principles of an ASCIImage are the following:

* an ASCIImage is a sequence of equal-length lines, filled by pixels;

* all whitespace is ignored, but pixels should be equally spaced;

* pixels can be marked or unmarked; marks are numbered according to the system
  1, 2, …, 9, A, B, …, Z, a, b, … z; anything else is an unmarked pixel;

* a path is defined by consecutive marks (no gaps), or repeated/isolated
  marks:

	* single-instance consecutive marks indicate a polygon;
	* double marks indicate invidual straight lines;
	* marks repeated more than once denote an ellipse inscribed in
	  the rectangular convex hull of the repeated marks;
	* isolated marks denote individual pixels;

## SVG conversion

To convert an ASCIImage to an SVG, the following conventions are
applied:

* each pixel row/column of the ASCIImage is assumed to be made of 10 SVG
  units;
* each mark is placed at the center of the pixel, i.e. at `rc*10 + 5`
  SVG units;

