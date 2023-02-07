use crate::lexer::ProgramContext;
use Token::*;

#[derive(Debug, Clone)]
pub enum Token {
    BOF,
    EOF,

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
    QuestionOperator, // ?
    DotOperator, // .
    ScopeResolutionOperator, // ::
    DoubleArrowOperator, // =>
}

impl Token {
    pub fn as_string(&self) -> String {
        match &self {
            BOF                             => String::from("BOF"),
            EOF                             => String::from("EOF"),
            IntToken(n)                     => n.to_string(),
            FloatToken(n)                   => n.to_string(),
            StringToken(string)             => string.clone(),
            CharToken(character)            => character.to_string(),
            Identifier(identifier)          => identifier.clone(),
            TrueKeyword                     => String::from("true"),
            FalseKeyword                    => String::from("false"),
            ImportKeyword                   => String::from("import"),
            UseKeyword                      => String::from("use"),
            FnKeyword                       => String::from("fn"),
            StructKeyword                   => String::from("struct"),
            EnumKeyword                     => String::from("enum"),
            TraitKeyword                    => String::from("trait"),
            InstanceKeyword                 => String::from("instance"),
            TypeKeyword                     => String::from("type"),
            ConstKeyword                    => String::from("const"),
            LetKeyword                      => String::from("let"),
            ForKeyword                      => String::from("for"),
            InKeyword                       => String::from("in"),
            IfKeyword                       => String::from("if"),
            ElseKeyword                     => String::from("else"),
            WhileKeyword                    => String::from("while"),
            LoopKeyword                     => String::from("loop"),
            TryKeyword                      => String::from("try"),
            CatchKeyword                    => String::from("catch"),
            OrKeyword                       => String::from("or"),
            AndKeyword                      => String::from("and"),
            NotKeyword                      => String::from("not"),
            ReturnKeyword                   => String::from("return"),
            BreakKeyword                    => String::from("break"),
            ContinueKeyword                 => String::from("continue"),
            SuperKeyword                    => String::from("super"),
            SelfKeyword                     => String::from("self"),
            I8Keyword                       => String::from("i8"),
            I16Keyword                      => String::from("i16"),
            I32Keyword                      => String::from("i32"),
            I64Keyword                      => String::from("i64"),
            I128Keyword                     => String::from("i128"),
            ISizeKeyword                    => String::from("isize"),
            U8Keyword                       => String::from("u8"),
            U16Keyword                      => String::from("u16"),
            U32Keyword                      => String::from("u32"),
            U64Keyword                      => String::from("u64"),
            U128Keyword                     => String::from("u128"),
            USizeKeyword                    => String::from("usize"),
            F32Keyword                      => String::from("f32"),
            F64Keyword                      => String::from("f64"),
            BoolKeyword                     => String::from("bool"),
            CharKeyword                     => String::from("char"),
            LeftCurlyBracketOperator        => String::from("{"),
            RightCurlyBracketOperator       => String::from("}"),
            LeftSquareBracketOperator       => String::from("["),
            RightSquareBracketOperator      => String::from("]"),
            LeftParenthesisOperator         => String::from("("),
            RightParenthesisOperator        => String::from(")"),
            SemicolonOperator               => String::from(";"),
            CommaOperator                   => String::from(","),
            ColonOperator                   => String::from(":"),
            EqualOperator                   => String::from("="),
            PipeOperator                    => String::from("|"),
            DoubleEqualOperator             => String::from("=="),
            BangEqualOperator               => String::from("!="),
            LeftChevronOperator             => String::from("<"),
            RightChevronOperator            => String::from(">"),
            LeftChevronEqualOperator        => String::from("<="),
            RightChevronEqualOperator       => String::from(">="),
            DoubleLeftChevronOperator       => String::from("<<"),
            DoubleRightChevronOperator      => String::from(">>"),
            PlusOperator                    => String::from("+"),
            MinusOperator                   => String::from("-"),
            StarOperator                    => String::from("*"),
            SlashOperator                   => String::from("/"),
            PercentOperator                 => String::from("%"),
            DoubleStarOperator              => String::from("**"),
            CaretOperator                   => String::from("^"),
            AmpersandOperator               => String::from("&"),
            TildeOperator                   => String::from("~"),
            DoubleLeftChevronEqualOperator  => String::from("<<="),
            DoubleRightChevronEqualOperator => String::from(">>="),
            PlusEqualOperator               => String::from("+="),
            MinusEqualOperator              => String::from("-="),
            StarEqualOperator               => String::from("*="),
            SlashEqualOperator              => String::from("/="),
            PercentEqualOperator            => String::from("%="),
            DoubleStarEqualOperator         => String::from("**="),
            CaretEqualOperator              => String::from("^="),
            AmpersandEqualOperator          => String::from("&="),
            TildeEqualOperator              => String::from("~="),
            PipeEqualOperator               => String::from("|="),
            BangOperator                    => String::from("!"),
            DoubleBangOperator              => String::from("!!"),
            QuestionOperator                => String::from("?"),
            DotOperator                     => String::from("."),
            ScopeResolutionOperator         => String::from("::"),
            DoubleArrowOperator             => String::from("=>"),
        }
    }

    pub fn string_to_token_content(s: String, context: &ProgramContext) -> Option<Token> {
        match context {
            ProgramContext::NormalContext => match s.as_str() {
                "true"       => Some(TrueKeyword),
                "false"      => Some(FalseKeyword),
                "import"     => Some(ImportKeyword),
                "use"        => Some(UseKeyword),
                "fn"         => Some(FnKeyword),
                "struct"     => Some(StructKeyword),
                "enum"       => Some(EnumKeyword),
                "trait"      => Some(TraitKeyword),
                "instance"   => Some(InstanceKeyword),
                "type"       => Some(TypeKeyword),
                "const"      => Some(ConstKeyword),
                "let"        => Some(LetKeyword),
                "for"        => Some(ForKeyword),
                "in"         => Some(InKeyword),
                "if"         => Some(IfKeyword),
                "else"       => Some(ElseKeyword),
                "while"      => Some(WhileKeyword),
                "loop"       => Some(LoopKeyword),
                "try"        => Some(TryKeyword),
                "catch"      => Some(CatchKeyword),
                "or"         => Some(OrKeyword),
                "and"        => Some(AndKeyword),
                "not"        => Some(NotKeyword),
                "return"     => Some(ReturnKeyword),
                "break"      => Some(BreakKeyword),
                "continue"   => Some(ContinueKeyword),
                "super"      => Some(SuperKeyword),
                "self"       => Some(SelfKeyword),
                "{"          => Some(LeftCurlyBracketOperator),
                "}"          => Some(RightCurlyBracketOperator),
                "["          => Some(LeftSquareBracketOperator),
                "]"          => Some(RightSquareBracketOperator),
                "("          => Some(LeftParenthesisOperator),
                ")"          => Some(RightParenthesisOperator),
                ";"          => Some(SemicolonOperator),
                ","          => Some(CommaOperator),
                ":"          => Some(ColonOperator),
                "="          => Some(EqualOperator),
                "|"          => Some(PipeOperator),
                "=="         => Some(DoubleEqualOperator),
                "!="         => Some(BangEqualOperator),
                "<"          => Some(LeftChevronOperator),
                ">"          => Some(RightChevronOperator),
                "<="         => Some(LeftChevronEqualOperator),
                ">="         => Some(RightChevronEqualOperator),
                "<<"         => Some(DoubleLeftChevronOperator),
                ">>"         => Some(DoubleRightChevronOperator),
                "+"          => Some(PlusOperator),
                "-"          => Some(MinusOperator),
                "*"          => Some(StarOperator),
                "/"          => Some(SlashOperator),
                "%"          => Some(PercentOperator),
                "**"         => Some(DoubleStarOperator),
                "^"          => Some(CaretOperator),
                "&"          => Some(AmpersandOperator),
                "~"          => Some(TildeOperator),
                "<<="        => Some(DoubleLeftChevronEqualOperator),
                ">>="        => Some(DoubleRightChevronEqualOperator),
                "+="         => Some(PlusEqualOperator),
                "-="         => Some(MinusEqualOperator),
                "*="         => Some(StarEqualOperator),
                "/="         => Some(SlashEqualOperator),
                "%="         => Some(PercentEqualOperator),
                "**="        => Some(DoubleStarEqualOperator),
                "^="         => Some(CaretEqualOperator),
                "&="         => Some(AmpersandEqualOperator),
                "~="         => Some(TildeEqualOperator),
                "|="         => Some(PipeEqualOperator),
                "!"          => Some(BangOperator),
                "!!"         => Some(DoubleBangOperator),
                "."          => Some(DotOperator),
                "::"         => Some(ScopeResolutionOperator),
                "=>"         => Some(DoubleArrowOperator),
                _            => None,
            },

            ProgramContext::TypeContext => match s.as_str() {
                "i8"         => Some(I8Keyword),
                "i16"        => Some(I16Keyword),
                "i32"        => Some(I32Keyword),
                "i64"        => Some(I64Keyword),
                "i128"       => Some(I128Keyword),
                "isize"      => Some(ISizeKeyword),
                "u8"         => Some(U8Keyword),
                "u16"        => Some(U16Keyword),
                "u32"        => Some(U32Keyword),
                "u64"        => Some(U64Keyword),
                "u128"       => Some(U128Keyword),
                "usize"      => Some(USizeKeyword),
                "f32"        => Some(F32Keyword),
                "f64"        => Some(F64Keyword),
                "bool"       => Some(BoolKeyword),
                "char"       => Some(CharKeyword),
                "{"          => Some(LeftCurlyBracketOperator),
                "}"          => Some(RightCurlyBracketOperator),
                "["          => Some(LeftSquareBracketOperator),
                "]"          => Some(RightSquareBracketOperator),
                "("          => Some(LeftParenthesisOperator),
                ")"          => Some(RightParenthesisOperator),
                ";"          => Some(SemicolonOperator),
                ","          => Some(CommaOperator),
                ":"          => Some(ColonOperator),
                "="          => Some(EqualOperator),
                "|"          => Some(PipeOperator),
                "=="         => Some(DoubleEqualOperator),
                "!="         => Some(BangEqualOperator),
                "<"          => Some(LeftChevronOperator),
                ">"          => Some(RightChevronOperator),
                "<="         => Some(LeftChevronEqualOperator),
                ">="         => Some(RightChevronEqualOperator),
                "+"          => Some(PlusOperator),
                "-"          => Some(MinusOperator),
                "*"          => Some(StarOperator),
                "/"          => Some(SlashOperator),
                "%"          => Some(PercentOperator),
                "**"         => Some(DoubleStarOperator),
                "^"          => Some(CaretOperator),
                "&"          => Some(AmpersandOperator),
                "~"          => Some(TildeOperator),
                "<<="        => Some(DoubleLeftChevronEqualOperator),
                ">>="        => Some(DoubleRightChevronEqualOperator),
                "+="         => Some(PlusEqualOperator),
                "-="         => Some(MinusEqualOperator),
                "*="         => Some(StarEqualOperator),
                "/="         => Some(SlashEqualOperator),
                "%="         => Some(PercentEqualOperator),
                "**="        => Some(DoubleStarEqualOperator),
                "^="         => Some(CaretEqualOperator),
                "&="         => Some(AmpersandEqualOperator),
                "~="         => Some(TildeEqualOperator),
                "|="         => Some(PipeEqualOperator),
                "!"          => Some(BangOperator),
                "!!"         => Some(DoubleBangOperator),
                "."          => Some(DotOperator),
                "::"         => Some(ScopeResolutionOperator),
                "=>"         => Some(DoubleArrowOperator),
                "?"          => Some(QuestionOperator),
                _            => None,
            }
        }
    }
}
