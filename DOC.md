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
These tokens are then returned to the parser alongside a potential error value
one by one each time the lexer is told to iterate a new token.

The lexer will take a `ProgramContext` which will help clear up ambiguity in
the lexing process, for example, to distinguish `>>` as one double-character
token for the right bitshift operator from `>>` as two single-character tokens
for nested types such as `Array<Array<i32>>`.

```rs
struct Lexer {
    code: String,
    filename: String,
    chars: Iterator<String>,
    index: usize,
    column: usize,
    line: usize,
}

enum ProgramContext {
    NormalContext,
    TypeContext,
}

impl Lexer {
    fn new(code: String, filename: String) {
        Lexer {
            code,
            filename,
            chars: code.chars(),
            index: 0,
            column: 0,
            line: 0,
        }
    }

    fn next_char(&mut self) -> Option<char> {
        let current_char: char = self.chars.next()

        if current_char == '\n' {
            self.line += 1;
            self.column = 0;
        }

        self.column += 1;
        self.index += 1;

        current_char
    }

    fn next(&mut self, context: ProgramContext) -> Option<Self::Item> {
        // Get next token
        match self.next_char() {
            Some(x) if x.is_whitespace() => {},
            Some(x) if x.is_digit(10)    => self.lex_number(x),
            Some(x) if x == '"'          => self.lex_string(),
            Some(x) if x == '\''         => self.lex_char(),
            Some(x) if
                x.is_ascii_punctuation()
                && x != '_'              => self.lex_operator(x, context),
            Some(x)                      => self.lex_word(x),
            None                         => None,
        }
    }
}
```

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

### Lexer Tokens

```rs
struct Token {
    content: TokenContent,
    context: Box<Lexer>,
}

enum TokenContent {
    // Literals and Identifiers
    
    IntToken(isize),
    FloatToken(f64),
    StringToken(String),
    CharToken(char),
    Identifier(String),

    // Keywords

    TrueKeyword,
    FalseKeyword,
    ImportKeyword,
    UseKeyword,
    FnKeyword,
    StructKeyword,
    EnumKeyword,
    TraitKeyword,
    InstanceKeyword,
    TypeKeyword,
    ConstKeyword,
    LetKeyword,
    ForKeyword,
    InKeyword,
    IfKeyword,
    ElseKeyword,
    WhileKeyword,
    LoopKeyword,
    TryKeyword,
    CatchKeyword,
    OrKeyword,
    AndKeyword,
    NotKeyword,
    ReturnKeyword,
    BreakKeyword,
    ContinueKeyword,
    SuperKeyword,
    SelfKeyword,
    I8Keyword, // i8
    I16Keyword, // i16
    I32Keyword, // i32
    I64Keyword, // i64
    I128Keyword, // i128
    ISizeKeyword, // isize
    U8Keyword, // u8
    U16Keyword, // u16
    U32Keyword, // u32
    U64Keyword, // u64
    U128Keyword, // u128
    USizeKeyword, // usize
    F32Keyword, // f32
    F64Keyword, // f64
    BoolKeyword, // bool
    CharKeyword, // char

    // Operators

    LeftCurlyBracketOperator, // {
    RightCurlyBracketOperator, // }
    LeftSquareBracketOperator, // [
    RightSquareBracketOperator, // ]
    LeftParenthesisOperator, // (
    RightParenthesisOperator, // )
    SemicolonOperator, // ;
    CommaOperator, // ,
    ColonOperator, // :
    EqualOperator, // =
    PipeOperator, // |
    DoubleEqualOperator, // ==
    BangEqualOperator, // !=
    LeftChevronOperator, // <
    RightChevronOperator, // >
    LeftChevronEqualOperator, // <=
    RightChevronEqualOperator, // >=
    DoubleLeftChevronOperator, // <<
    DoubleRightChevronOperator, // >>
    PlusOperator, // +
    MinusOperator, // -
    StarOperator, // *
    SlashOperator, // /
    PercentOperator, // %
    DoubleStarOperator, // **
    CaretOperator, // ^
    AmpersandOperator // &
    TildeOperator // ~
    DoubleLeftChevronEqualOperator, // <<=
    DoubleRightChevronEqualOperator, // >>=
    PlusEqualOperator, // +=
    MinusEqualOperator, // -=
    StarEqualOperator, // *=
    SlashEqualOperator, // /=
    PercentEqualOperator, // %=
    DoubleStarEqualOperator, // **=
    CaretEqualOperator, // ^=
    AmpersandEqualOperator // &=
    TildeEqualOperator // ~=
    PipeEqualOperator, // |=
    BangOperator, // !
    DoubleBangOperator, // !!
    DotOperator, // .
    ScopeResolutionOperator, // ::
    DoubleArrowOperator, // =>
}
```

## Parser

The parser takes a list of tokens as input and recursively generates an
abstract syntax tree of nodes.

### Top-Level Statements

Top-level statements are any statements that can be placed directly in the main
body of the program.

<sub>Examples of top-level statements:</sub>

 - `import`
 - `use`
 - `fn`
 - `struct`
 - `enum`
 - `trait`
 - `instance`
 - `type`
 - `const`
 - `static`

The keywords above are actively searched for in the main function of the
parser.

### Grammar Definition

```ebnf
NOTATION:
    { x } = x at least zero times
    [ x ] = optional x
    x | y = either x or y
    { x }, = [ x { "," x } [ "," ] ] = x at least zero times, comma-separated
    { x }; = [ x { ";" x } ";" ] = x at least zero times, semicolon-separated, semicolon final

GRAMMAR:
    program         = { top_item | item } EOF

    top_item        = mod | trait | instance | test
    mod             = "mod" ID ( ";" | "{" { top_item | item } "}" )
    trait           = "trait" ID [ "<" { ID }, ">" ] "{" { item } "}"
    instance        = "instance" ID [ "<" { ID }, ">" ] type "{" { item } "}"
    test            = "test" ID block

    item            = fn | struct | enum | type_alias | const_item | use
    fn              = "fn" ID "(" { ID ":" type }, ")" [ ":" type ] ( [ "=" expression ] ";" | block )
    struct          = "struct" ID [ "<" { ID }, ">" ] "{" { ID ":" type }, "}"
    enum            = "enum" ID [ "<" { ID }, ">" ] "{" { ID [ "(" { type }, ")" ] } "}"
    type_alias      = "type" ID "=" type ";"
    const_item      = "const" ID "=" literal ";"
    use             = "use" path ";"

    statement       = expression | let | const
    let             = "let" pattern "=" expression
    const           = "const" pattern "=" expression

    expression      = block | for | if | while | loop | match | return | break | continue | closure | assign
    block           = "{" { statement }; [ expression ] "}"
    for             = "for" pattern "in" expression block
    if              = "if" expression block [ "else" ( if | block ) ]
    while           = "while" expression block
    loop            = "loop" block
    match           = "match" expression "{" { pattern "=>" expression }, "}"
    return          = "return" [ expression ]
    break           = "break" [ expression ]
    continue        = "continue"
    closure         = "|" { ID ":" type }, "|" expression

    assign          = try | ID assign_op expression
    try             = [ "try" ] range
    range           = or [ ( ".." | "..=" ) or ]
    or              = and { "or" and }
    and             = compare { "and" compare }
    compare         = bitwise_or { ( "==" | "!=" | ">=" | "<=" | ">" | "<" ) bitwise_or }
    bitwise_or      = bitwise_xor { "|" bitwise_xor }
    bitwise_xor     = bitwise_and { "^" bitwise_and }
    bitwise_and     = bitshift { "&" bitshift }
    bitshift        = term { ( "<<" | ">>" ) term }
    term            = factor { ( "+" | "-" | "+%" | "-%" ) factor }
    factor          = exponent { ( "*" | "/" | "%" | "*%" ) exponent }
    exponent        = cast { ( "**" | "**%" ) cast }
    cast            = prefix [ ":" type ]
    prefix          = { "not" | "~" | "-" | "-%" } dot
    dot             = suffix { "." atom }
    suffix          = call { "&" | "*" }
    call            = path { "(" { expression }, ")" | "[" expression "]" }
    path            = atom | { ID "::" } ID
    atom            = ID | literal | "(" expression ")" | "[" { expression }, "]"
    literal         = INT | FLOAT | CHAR | STR | "true" | "false"

    type            = pointer | array | optional | result | id_type | primitive
    pointer         = type "&"
    array           = "[" type "]"
    optional        = type "?"
    result          = type "!"
    id_type         = ID [ "<" { type }, ">" ]
    primitive       = "i8"   | "i16" | "i32"  | "i64"  | "i128" | "isize"
                    | "u8"   | "u16" | "u32"  | "u64"  | "u128" | "usize"
                    | "f32"  | "f64" | "char" | "bool"
    
    pattern         = id_pattern  | enum_pattern  | struct_pattern | array_pattern
                    | ref_pattern | blank_pattern | rest_pattern   | literal_pattern
                    | "(" pattern ")"
    id_pattern      = ID
    enum_pattern    = ID "(" { pattern }, ")"
    struct_pattern  = ID "{" { ID ":" pattern }, "}"
    array_pattern   = "[" { pattern }, "]"
    ref_pattern     = pattern "&"
    blank_pattern   = "_"
    rest_pattern    = "..."
    literal_pattern = CHAR | STR | "true" | "false"
```

### AST Nodes

```rs {filename="main.rs"}
// Item nodes

enum Item {
    Import {
        imported: String,
    },
    Use {
        used: String,
    },
    Function {
        header: FunctionHeader,
        body: Block,
    },
    Struct {
        name: String,
        type_parameters: Vec<String>,
        fields: Vec<StructField>,
    },
    Enum {
        name: String,
        type_parameters: Vec<String>,
        fields: Vec<EnumField>,
    },
    Trait {
        name: String,
        type_parameters: Vec<String>,
        items: Vec<Items>,
    },
    Instance {
        trait_: Trait,
        type_: Type,
        items: Vec<Items>,
    },
    TypeAlias {
        newtype: String,
        oldtype: Type,
    },
    ConstItem {
        name: String,
        type_: Type,
        value: Expression,
    },
    StaticItem {
        name: String,
        type_: Type,
        value: Expression,
    },
}

struct FunctionHeader {
    name: String,
    parameters: Option<Vec<String>>,
    types: Vec<Type>,
    return_type: Type,
}

struct StructField {
    name: String,
    type_: Type,
}

struct EnumField {
    name: String,
    types: Vec<Type>,
}

// Expression nodes

enum Expression {
    ForExpression {
        pattern: Pattern,
        iterator: Expression,
        body: Block,
    },
    IfExpression {
        condition: Expression,
        body: Block,
        alternate: Block,
    },
    WhileExpression {
        condition: Expression,
        body: Block,
    },
    LoopExpression {
        body: Block,
    },
    MatchExpression {
        discriminant: Expression,
        branches: Vec<MatchBranch>,
    },
    BlockExpression {
        body: Block,
    },
    TryExpression {
        expression: Expression,
    },
    CatchExpression {
        expression: Expression,
        result: Expression,
    },
    ArrayExpression {
        type_: Type,
        elements: Vec<Expression>,
    },
    CallExpression {
        callee: Expression,
        arguments: Vec<Expression>,
    },
    IndexExpression {
        indexed: Expression,
        argument: Expression,
    },
    FieldExpression {
        left: Expression,
        right: String,
    },
    TypeCastExpression {
        value: Expression,
        type_: Type,
    },
    ReturnExpression {
        returned: Option<Expression>,
    },
    BreakExpression {
        returned: Option<Expression>,
    },
    ContinueExpression,
    StructExpression {
        struct_: String,
        fields: Vec<StructExpressionField>,
    },
    PathExpression {
        source: PathSegment,
        member: PathSegment,
    },
    BinaryOp {
        op: Operator,
        left: Expression,
        right: Expression,
    },
    UnaryOp {
        op: Operator,
        child: Expression,
    },
    Variable {
        name: String,
    },
    IntLiteral {
        value: isize,
    },
    FloatLiteral {
        value: f64,
    },
    StringLiteral {
        value: String,
    },
    CharLiteral {
        value: char,
    },
    BooleanLiteral {
        value: bool,
    },
}

struct Block {
    statements: Vec<Statement>,
    expression: Expression,
}

struct MatchBranch {
    pattern: Pattern,
    consequent: Expression,
}

struct StructExpressionField {
    name: String,
    expression: Expression,
}

enum Operator {
    AddOperator,
    SubtractOperator,
    MultiplyOperator,
    DivideOperator,
    ModuloOperator,
    NegateOperator,
}

enum PathSegment {
    PathIdentifier {
        id: String
    },
    SuperPath,
    SelfPath,
}

// Statement nodes

enum Statement {
    LetStatement {
        pattern: Pattern,
        expression: Expression,
    },
    ConstStatement {
        pattern: Pattern,
        expression: Expression,
    },
    ExpressionStatement {
        expression: Expression,
    },
}

enum Type {
    Int8,
    Int16,
    Int32,
    Int64,
    Int128,
    IntSize,
    UInt8,
    UInt16,
    UInt32,
    UInt64,
    UInt128,
    UIntSize,
    Float32,
    Float64,
    Boolean,
    Char,
    Array {
        type_: Type,
        length: usize,
    },
    Pointer {
        pointed: Type,
    },
    Type {
        name: String,
    },
    GenericType {
        name: String,
        types: Vec<Type>,
    },
    Trait {
        trait_: Trait,
    },
}

enum Trait {
    Trait {
        name: String,
    },
    GenericTrait {
        name: String,
        types: Vec<Type>,
    },
}
```

## Interpreter

The interpreter takes an abstract syntax tree as input and recursively explores
each node and runs it.
