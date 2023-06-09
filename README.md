# HUFETS: **HU**man-**F**riendly **E**xpressions for **T**ext **S**earching

HUFETS is a minimalistic "regex" for searching within written text. It's meant to be:
* Forgiving to write
* Easily readable even for non-programmers
* Safe


The basic gist is:

* Letters, digits and most punctuation match themselves
* Things inside quotes are matched literally
* Whitespace matches non-alphanumeric characters
* `_` matches alphanumeric characters
* `/` matches options
* `...` matches any characters


## Installation

HUFETS is still unstable and the syntax may be subject to change. While I plan on publishing it to [LuaRocks](https://luarocks.org/) when it's stable, for now, install it by building manually:
```
git clone https://github.com/RiskoZoSlovenska/hufets
cd hufets
luarocks make
```


## Syntax

Note that this specification is still a work in progress, and some smaller details, such as handling of edge cases, may change.

### General

As mentioned, alphanumerics and most punctuation match themselves. Additionally, the matched string must be flanked by non-alphanumerics on both sides (i.e. `a` matches `a` and `b a c` but not `ab` or `bac`).

Some magic characters, such as `_`s and `...`s, will try to match multiple characters lazily, *but they do not backtrack*. The rationale behind this is that backtracking is not needed for most of HUFETS' use cases and only opens up possibilities for [catastrophic backtracking](https://www.regular-expressions.info/catastrophic.html).

### Quotes

With the exception of the single quote (see below), any characters between an opening quote (`"`) and a closing quote (also a `"`) are matched literally (without the quotes themselves). Quotes cannot be escaped inside quotes; use a single quote. When there is an unbalanced amount of quotes in the pattern, the last quote is matched literally.

Single quotes (`'`s) are sort of an exception to everything; they will match either a single quote or a double quote.

### Spaces

Any sequences of whitespace characters in the pattern matches any sequence of non-alphanumeric characters. At least one character must be matched and the rest of the characters are matched lazily, so that the pattern `a !b` matches `a !b` and `a ! !b`, but not `a ! b`, `a!b` or `a  b`. Flanking spaces in the pattern signify that the string must also be flanked by whitespace.

### Underscores

A sequence of underscores (`_`s) in the pattern matches a sequence of alphanumeric characters. The number of underscores in a row indicates the minimum number of characters to match; `_` will match at least one character and `___` at least three. Additional characters are matched lazily, so that the pattern `a_b` matches `aab`, `acdb` and `abb`, but not `ab`. Note that because underscores don't backtrack, `a_b` will *not* match `abbb`.

### Slashes

Multiple sequences of alphanumerics and underscores separated by one or more slashes (`/`s) match one of the sequences (i.e. `a/b_` will try to match both `a` and `b_`). Any leading, trailing, or duplicate slashes are ignored: `//a///b/` is equal to `a/b`, and `///` (or any number of repeated slashes) is equal to `""` (a literal match for the empty string).

### Ellipses

An ellipse (a sequence of three periods, `...`, *not* the [Unicode character](https://www.compart.com/en/unicode/U+2026)) matches any sequence of characters. Unlike other matches, this match does not have to match a character at all, but still does not backtrack. For example, `a...b` matches `ab`, `aab` and `ac e fb`, but does not match `abb`.

As a special case, if the ellipse is both preceded and followed by whitespace, the whitespace that follows it can overlap with the preceding space. This ensures that `a ... b` matches `a b` (but not `a cb` or `ac b`).

### Anchors

Anchoring is done using the pipe character (`|`) at the beginning or the end of the pattern. For example, `|a` matches `a b` but not `b a`. When found anywhere else in the pattern, the pipe is interpreted literally. Edge cases in which the pattern consists of only the pipe, or only the pipe and whitespace may result in the pattern matching empty strings/whitespace sequences (albeit ones that still have to follow the implicit no-alphanumerics-on-sides rule) at the beginning or end of the string. For example, ` |` will match and `a  `, but not the empty string or `a` (whitespace must be matched), `  a` (whitespace must be at the end), or `a ` (matched whitespace must not be flanked by alphanumerics).

### Manual

If the pattern begins with an exclamation mark (`!`), the rest of the pattern is passed to lpeg's `re.compile` function and the resulting object is used as the body of the pattern. Positional captures are inserted on either side, the pattern becomes subject to the usual no-flanking-alphanumerics rule, is allowed to match anywhere in a string, and has any other captures discarded.

If the pattern begins with two exclamation marks, the rest of the pattern is passed to lpeg's `re.compile` and the resulting object is used as the matcher, without any extra bells or whistles appended to it. The pattern is expected to contain two positional captures (the start and the end); including any other captures will cause undefined behaviour.

Exclamation marks anywhere else in the pattern are interpreted literally.


## Docs

The library returns two functions:

### compile(pattern, allowManual)

Parses `pattern` (a string) as a HUFETS pattern and returns the resulting lpeg object. If parsing fails, the first return value will be nil and the second will be an error string. The value of the `allowManual` flag (a boolean) determines whether HUFETS will parse [manual patterns](#manual). Compile patterns are stored in a weak table and successive calls with the same arguments may yield the same object.

### match(str, pattern, start, allowManual)

This function is mostly equal to `compile(pattern, allowManual):match(str, start)`, except that it also handles errors and validates that the return values are numbers. If the pattern fails to parse or throws an error while matching (should only happen when using [manual patterns](#manual)) the function will return two `nil`s followed by a string error message. If the pattern fails to match, three `nil`s will be returned.


## Development

Run tests:
```
lua test.lua
```
