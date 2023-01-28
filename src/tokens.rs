pub struct Token {
    pub content: TokenContent,
    pub context: TokenContext,
}

#[derive(Clone)]
pub struct TokenContext {
    pub filename: String,
    pub index: usize,
    pub column: usize,
    pub line: usize,
}

#[derive(Debug)]
pub enum TokenContent {
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
    AmpersandOperator, // &
    TildeOperator, // ~
    DoubleLeftChevronEqualOperator, // <<=
    DoubleRightChevronEqualOperator, // >>=
    PlusEqualOperator, // +=
    MinusEqualOperator, // -=
    StarEqualOperator, // *=
    SlashEqualOperator, // /=
    PercentEqualOperator, // %=
    DoubleStarEqualOperator, // **=
    CaretEqualOperator, // ^=
    AmpersandEqualOperator, // &=
    TildeEqualOperator, // ~=
    PipeEqualOperator, // |=
    BangOperator, // !
    DoubleBangOperator, // !!
    DotOperator, // .
    ScopeResolutionOperator, // ::
    DoubleArrowOperator, // =>
}