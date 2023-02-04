use crate::lexer::{*, ProgramContext::*};
use crate::nodes::*;
use crate::tokens::Token;

pub struct SyntaxError {
    pub error_type: SyntaxErrorType,
    pub context: LexerContext,
}

pub enum SyntaxErrorType {
    LexerError(LexerErrorType),
    AtomExpected,
    ClosingBracketExpected,
    TypeExpected,
    BlockExpected,
    SemicolonExpected,
}

impl Lexer {
    // pub fn parse(&mut self) -> Result<Vec<Item>, SyntaxError> {
    //     let items: Vec<Item> = Vec::new();

    //     loop {
    //         match self.parse_expression() {
    //             Ok(_x) => {},
    //             Err(_x) => break,
    //         }
    //     }

    //     Ok(items)
    // }

    pub fn parse_block(&mut self) -> Result<Block, Vec<SyntaxError>> {
        match self.next_token(NormalContext)? {
            Token::LeftCurlyBracketOperator => {},
            _ => return Err(self.error(SyntaxErrorType::BlockExpected)),
        }

        let mut statements = Vec::new();

        loop {
            if let Token::RightCurlyBracketOperator = self.next_token(NormalContext)? { break; }
            let statement = self.parse_statement()?;
            match self.next_token(NormalContext)? {
                Token::SemicolonOperator => statements.push(statement),
                Token::RightCurlyBracketOperator => match statement {
                    Statement::ExpressionStatement { expression } => {
                        return Ok(Block { statements, expression: Some(Box::new(expression)) })
                    },
                    _ => return Err(self.error(SyntaxErrorType::SemicolonExpected)),
                }
                _ => return Err(self.error(SyntaxErrorType::SemicolonExpected)),
            }
        }
        
        Ok(Block { statements, expression: None })
    }

    fn parse_statement(&mut self) -> Result<Statement, Vec<SyntaxError>> {
        todo!()
    }

    fn parse_expression(&mut self) -> Result<Expression, Vec<SyntaxError>> {
        self.parse_atom()
    }

    fn parse_atom(&mut self) -> Result<Expression, Vec<SyntaxError>> {
        match self.next_token(NormalContext)? {
            Token::IntToken(int)         => Ok(Expression::IntLiteral { value: int }),
            Token::FloatToken(float)     => Ok(Expression::FloatLiteral { value: float }),
            Token::StringToken(string)   => Ok(Expression::StringLiteral { value: string }),
            Token::CharToken(char)       => Ok(Expression::CharLiteral { value: char }),
            Token::Identifier(id)        => Ok(Expression::Variable { name: id }),
            Token::TrueKeyword           => Ok(Expression::BooleanLiteral { value: true }),
            Token::FalseKeyword          => Ok(Expression::BooleanLiteral { value: false }),
            _                            => Err(self.error(SyntaxErrorType::AtomExpected)),
        }
    }

    fn parse_type_atom(&mut self) -> Result<Type, Vec<SyntaxError>> {
        match self.next_token(TypeContext)? {
            Token::I8Keyword => Ok(Type::Int8),
            Token::I16Keyword => Ok(Type::Int16), // i16
            Token::I32Keyword => Ok(Type::Int32), // i32
            Token::I64Keyword => Ok(Type::Int64), // i64
            Token::I128Keyword => Ok(Type::Int128), // i128
            Token::ISizeKeyword => Ok(Type::IntSize), // isize
            Token::U8Keyword => Ok(Type::UInt8), // u8
            Token::U16Keyword => Ok(Type::UInt16), // u16
            Token::U32Keyword => Ok(Type::UInt32), // u32
            Token::U64Keyword => Ok(Type::UInt64), // u64
            Token::U128Keyword => Ok(Type::UInt128), // u128
            Token::USizeKeyword => Ok(Type::UIntSize), // usize
            Token::F32Keyword => Ok(Type::Float32), // f32
            Token::F64Keyword => Ok(Type::Float64), // f64
            Token::BoolKeyword => Ok(Type::Boolean), // bool
            Token::CharKeyword => Ok(Type::Char), // char
            Token::Identifier(id) => Ok(Type::Type { name: id }),
            _ => Err(self.error(SyntaxErrorType::TypeExpected)),
        }
    }

    fn parse_type(&mut self) -> Result<Type, Vec<SyntaxError>> {
        let mut type_ = self.parse_type_atom()?;
        loop {
            match self.next_token(TypeContext)? {
                Token::AmpersandOperator => type_ = Type::Pointer { pointed: Box::new(type_) },
                Token::QuestionOperator => type_ = Type::GenericType { name: String::from("Option"), types: vec![type_] },
                Token::PipeOperator => {
                    let type2 = self.parse_type()?;
                    type_ = Type::GenericType { name: "Result".to_string(), types: vec![type_, type2] }
                },
                Token::LeftSquareBracketOperator => {
                    self.next_token(TypeContext)?; // unsure, test this later
                    let inner_type = self.parse_type()?;
                    match self.next_token(TypeContext)? {
                        Token::SemicolonOperator => {},
                        _ => return Err(self.error(SyntaxErrorType::ClosingBracketExpected)),
                    }
                    let match self.next_token(TypeContext)? {
                        Token::IntToken(int) => 
                    }
                    match self.next_token(TypeContext)? {
                        Token::RightSquareBracketOperator => {},
                        _ => return Err(self.error(SyntaxErrorType::ClosingBracketExpected)),
                    }
                    type_ = Type::Array { type_: inner_type, length: () }
                }
                _ => break,
            }
        }
        Ok(type_)
    }

    fn next_token(&mut self, program_context: ProgramContext) -> Result<Token, Vec<SyntaxError>> {
        match self.next(program_context) {
            Ok(token) => Ok(token),
            Err(lex_error) => Err(self.lexer_error(lex_error)),
        }
    }

    fn peek_token(&mut self) -> Result<Token, Vec<SyntaxError>> {
        match self.peek() {
            Ok(token) => Ok(token),
            Err(lex_error) => Err(self.lexer_error(lex_error)),
        }
    }

    fn error(&self, error_type: SyntaxErrorType) -> Vec<SyntaxError> {
        let context = self.context.clone();
        vec![SyntaxError { error_type, context }]
    }

    fn lexer_error(&self, lex_error: LexerError) -> Vec<SyntaxError> {
        let error_type = SyntaxErrorType::LexerError(lex_error.error_type);
        let context = lex_error.context;
        vec![SyntaxError { error_type, context }]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lexer(filename: &str, code: &str) -> Lexer {
        Lexer::new(filename.to_string(), code.to_string())
    }

    #[test]
    fn parse_atom_int() {
        assert!(matches!(
            lexer("test.px", "2").parse_expression(),
            Ok(Expression::IntLiteral { value: x }) if x == 2
        ));
    }

    #[test]
    fn parse_atom_float() {
        assert!(matches!(
            lexer("test.px", "2.0").parse_expression(),
            Ok(Expression::FloatLiteral { value: x }) if x == 2.0
        ));
    }

    #[test]
    fn parse_atom_string() {
        assert!(matches!(
            lexer("test.px", "\"string\"").parse_expression(),
            Ok(Expression::StringLiteral { value: x }) if x == "string".to_string()
        ));
    }

    #[test]
    fn parse_atom_char() {
        assert!(matches!(
            lexer("test.px", "'c'").parse_expression(),
            Ok(Expression::CharLiteral { value: x }) if x == 'c'
        ));
    }

    #[test]
    fn parse_atom_true() {
        assert!(matches!(
            lexer("test.px", "true").parse_expression(),
            Ok(Expression::BooleanLiteral { value: x }) if x == true
        ));
    }

    #[test]
    fn parse_atom_false() {
        assert!(matches!(
            lexer("test.px", "false").parse_expression(),
            Ok(Expression::BooleanLiteral { value: x }) if x == false
        ));
    }
}