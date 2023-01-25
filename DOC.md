# Documentation

This file contains information pertaining the specifications of the
functionality of the Polarix Interpreter/Compiler.

## Terminology

A component is a step in processing, such as the lexer, parser, and
interpreter.

When a component is said to be "pointing to" something, namely the lexer and
parser, the component has a stored integer index value that points to a
specific value in a list of values. The lexer points to individual characters
and the parser points to individual tokens.

## Lexer / Tokenizer

The lexer (also known as a tokenizer) takes source code as a string as input
and splits it up into a series of tokens by iterating through it character by
character, pointing to each character with an unsigned integer index. Once the
lexer detects a character of a certain type, it enters a new mode and iterates
through characters that match the specifications of the respective token type.
These tokens are then returned to the main file alongside a potential error
value.

The lexer stores a structure containing the component's context which holds
information regarding the exact location of each character such as index,
column, line, file name and file text. This structure is referred to as a
**context**.

To iterate, the lexer increments the index and column values. If the pointed
character is a newline, the column value is set to zero and the line value is
incremented before incrementing the index and column values.

### Normal Mode

In the normal mode, the lexer ignores whitespace and enters different modes
depending on the type of character that the lexer is pointing to.

    Whitespace  => Skip Character
    Digit (0-9) => Number Mode
    (")         => String Mode
    (')         => Character Mode
    Punctuation => Operator Mode
    Else        => Word Mode

### Number Mode

In the number mode, the lexer iterates through digit characters as well as the
dot (.) and the underscore (_) characters. If the lexer points to a dot but the
mode had already encountered a dot, the mode will exit. Underscores are
ignored.

If the number contains a dot, the lexer tokenizes it as a float, otherwise as
an int.

If a word character (not whitespace, digit or punctuation) is encountered, the
lexer will error unless the last character is a dot in which case the dot and
word are lexed.

### String Mode

In the string mode, the lexer skips the initial double quote and keeps
iterating until a second double quote is reached. The lexer will handle escape
sequences and will ensure that escaped double quotes do not terminate the
string. The lexer will return an error if there is no double quote found by the
time a newline or EOF is reached.

### Character Mode

In the character mode, the lexer does the same as in the string mode but with
single quotes. In addition to the error provided by the string mode, if the
character is more than one character long, the lexer will return an error.

### Operator Mode

In the operator mode, the lexer iterates through punctuation characters. Once a
full string of punctuation characters is achieved, the lexer tries to match the
string with a pre-defined operator.

If none is found, the lexer tries to match the string without the last
character with an operator. This step is repeated with smaller and smaller
lengths until an operator is matched or when every length is checked.

If an operator is matched, the context's index is pointed immediately after the
operator. If no operator is matched, the lexer will return an error.

### Word Mode

In the word mode, the lexer simply iterates through word and number characters
including the underscore until a character that is neither of the two is
encountered. If the word ends up matching with a pre-defined keyword, the token
is labeled as a keyword; otherwise, it is labeled as an identifier.
