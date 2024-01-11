# HUFETS: **HU**man-**F**riendly **E**xpressions for **T**ext **S**earching

***Note:** I've decided to discontinue this project until further notice. I'm not entirely sure what I was thinking when I wrote it, but it's a bit of a mess that doesn't do a good job at what I actually needed it to do.*

HUFETS is a minimalistic "regex" for searching within written text. It's meant to be:
* Forgiving to write
* Easily readable even for non-programmers
* Safe (possibly; use at your own risk)


The basic gist is:

* Letters, digits and most punctuation match themselves
* Things inside quotes are matched literally
* Whitespace matches non-alphanumeric characters
* `_` matches alphanumeric characters
* `/` matches options
* `...` matches any characters


## Installation

HUFETS is still unstable and the syntax may be subject to change. Install it by building manually:
```
git clone https://github.com/RiskoZoSlovenska/hufets
cd hufets
luarocks make
```


## Syntax

Note that this specification is still a work in progress, and some smaller details, such as handling of edge cases, may change.

### Basics

Alphanumerics and most punctuation match themselves; `world!` would match in `hello world!`, for example. Spaces, however, can match any number of spaces or *non-alphanumerics*, meaning that `hello world` would not only match `hello world!`, but also `hello ! world`. All patterns are implicitly flanked by spaces: the matched string must be flanked by non-alphanumerics on both sides (i.e. `world` does not match in `hello worlds`).

Note that some magic characters, such as `_`s and `...`s, will try to match multiple characters lazily, *but they do not backtrack*. The rationale behind this is that backtracking is not needed for most of HUFETS' use cases and only opens up possibilities for [catastrophic backtracking](https://www.regular-expressions.info/catastrophic.html).

### Quotes

With the exception of the single quote (see below), any characters between an opening quote (`"`) and a closing quote (also a `"`) are matched literally (without the quotes themselves). Quotes cannot be escaped inside quotes; use a single quote. When there is an unbalanced amount of quotes in the pattern, the last quote is matched literally.

Single quotes (`'`s) are sort of an exception to everything; they will *always* match either a single quote or a double quote.

### Spaces

Any sequences of whitespace characters in the pattern matches any sequence of non-alphanumeric characters. At least one character must be matched and the rest of the characters are matched lazily, so that the pattern `a !b` matches `a !b` and `a ! !b`, but not `a ! b`, `a!b` or `a  b`.

Leading/trailing spaces in the pattern are ignored. Additionally, spaces behave differently when next to an [ellipse](#ellipses).

### Underscores

A sequence of underscores (`_`s) in the pattern matches a sequence of alphanumeric characters. The number of underscores in a row indicates the minimum number of characters to match; `_` will match at least one character and `___` at least three. Additional characters are matched lazily, so that the pattern `a_b` matches `aab`, `acdb` and `abb`, but not `ab`. Note that because underscores don't backtrack, `a_b` will *not* match `abbb`.

### Slashes

Multiple sequences of alphanumerics and underscores separated by one or more slashes (`/`s) match one of the sequences (i.e. `a/b_` will try to match both `a` and `b_`). Any leading, trailing, or duplicate slashes are ignored: `//a///b/` is equal to `a/b`, and `a /// b` is equal to `a b`.

### Ellipses

An ellipse (a sequence of three or more periods, `...`, *not* the [Unicode character](https://www.compart.com/en/unicode/U+2026)) is similar to an underscore; it matches one or more characters and still does not backtrack. Unlike the underscore, however, an ellipse can match nonalphanumerics. Additionally, any spaces around an ellipse lose their typical meaning: if the ellipse is lead or followed by a space, that side of the match must also match a word boundary. For example, `a...b` matches `aab` and `ac e fb`, but does not match `a b` or `ac b`; `a ...b` matches `a cb`, `a c fb`, but not `acb`.

Multiple ellipses separated by nothing but whitespace are parsed as a single ellipse. In other words, `a... ... b` is equivalent to `a... b`.

### Anchors

Anchoring is done using the pipe character (`|`) at the beginning or the end of the pattern. When a pattern is anchored, it can only matched if there are no *alphanumeric* characters between the the side of the pattern and the side of the string on which it was anchored. For example, `|a` matches `a b` and `*a*`, but not `b a`. An anchor can have whitespace on either side: ` |  a` is equivalent to `|a`. When found anywhere else in the pattern, the pipe is interpreted literally. Pipes are always interpreted as anchors where it is possible; `||` is two anchors, not an anchor followed by a pipe.

### Manual

If the pattern begins with an exclamation mark (`!`), the rest of the pattern is passed to lpeg's `re.compile` function and the resulting object is used as the body of the pattern. Positional captures are inserted on either side, the pattern becomes subject to the usual no-flanking-alphanumerics rule, is allowed to match anywhere in a string, and has any other captures discarded.

If the pattern begins with two exclamation marks, the rest of the pattern is passed to lpeg's `re.compile` and the resulting object is used as the matcher, without any extra bells or whistles appended to it. The pattern is expected to contain two positional captures (the start and the end); including any other captures will cause undefined behaviour.

Exclamation marks anywhere else in the pattern are interpreted literally.

Unlike the rest of HUFETS, this manual pattern must be explicitly enabled (see below) as it allows users to easily craft malicious patterns.

## "Malformed" patterns

HUFETS will never give up or throw an error when parsing a pattern or matching a string, even when presented with what looks like a malformed pattern. In cases like these, HUFETS will try its best to behave predictably. For example:
* A pattern that is empty, or contains only whitespace and magic characters (` `, `|`, `/`, etc.), only matches an empty string.
* Leading or trailing whitespace in patterns is ignored

However, the exact handling of "malformed" input might be implementation- and version-dependent in come cases, so for consistent results, avoid the following in patterns:
* Leading/trailing/duplicate unquoted slashes, i.e. `a//b`
* Leading/trailing whitespace (it can and should be trimmed)
* Empty patterns or patterns containing only magic characters
* Whitespace after/before anchors
* Ellipses containing more than 3 periods
* Duplicate ellipses separated by only whitespace, i.e. `a... ... ...b`
* Empty quotes

## Docs

The library returns two functions:

### compile(pattern, allowManual)

Parses `pattern` (a string) as a HUFETS pattern and returns the resulting lpeg object. If parsing fails, the first return value will be nil and the second will be an error string. The value of the `allowManual` flag (a boolean) determines whether HUFETS will parse [manual patterns](#manual). Compile patterns are stored in a weak table and successive calls with the same arguments may yield the same object.

### match(str, pattern, start, allowManual)

This function is mostly equal to `compile(pattern, allowManual):match(str, start)`, except that it also handles errors and validates that the return values are numbers. If the pattern fails to parse or throws an error while matching (should only happen when using [manual patterns](#manual)) the function will return two `nil`s followed by a string error message. If the pattern fails to match, three `nil`s will be returned.


## Development

Run tests:
```
luarocks make && lua test.lua
```
