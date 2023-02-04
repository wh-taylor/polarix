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
        match self.peek_token()? {
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
        match self.peek_token()? {
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
        match self.peek_token()? {
            Token::I8Keyword => Ok(Type::Int8),
            Token::I16Keyword => Ok(Type::Int16),
            Token::I32Keyword => Ok(Type::Int32),
            Token::I64Keyword => Ok(Type::Int64),
            Token::I128Keyword => Ok(Type::Int128),
            Token::ISizeKeyword => Ok(Type::IntSize),
            Token::U8Keyword => Ok(Type::UInt8),
            Token::U16Keyword => Ok(Type::UInt16),
            Token::U32Keyword => Ok(Type::UInt32),
            Token::U64Keyword => Ok(Type::UInt64),
            Token::U128Keyword => Ok(Type::UInt128),
            Token::USizeKeyword => Ok(Type::UIntSize),
            Token::F32Keyword => Ok(Type::Float32),
            Token::F64Keyword => Ok(Type::Float64),
            Token::BoolKeyword => Ok(Type::Boolean),
            Token::CharKeyword => Ok(Type::Char),
            Token::Identifier(id) => Ok(Type::Type { name: id }),
            Token::LeftSquareBracketOperator => {
                let inner_type = self.parse_type()?;

                match self.peek_token()? {
                    Token::SemicolonOperator => {},
                    _ => return Err(self.error(SyntaxErrorType::SemicolonExpected)),
                }
                
                let length: usize = match self.next_token(TypeContext)? {
                    Token::IntToken(int) if int >= 0 => int as usize,
                    _ => return Err(self.error(SyntaxErrorType::AtomExpected)),
                };
                
                match self.next_token(TypeContext)? {
                    Token::RightSquareBracketOperator => {},
                    _ => return Err(self.error(SyntaxErrorType::ClosingBracketExpected)),
                }

                Ok(Type::Array { type_: Box::new(inner_type), length })
            }
            _ => Err(self.error(SyntaxErrorType::TypeExpected)),
        }
    }

    fn parse_type(&mut self) -> Result<Type, Vec<SyntaxError>> {
        let mut type_ = self.parse_type_atom()?;
        loop {
            match self.next_token(TypeContext)? {
                Token::AmpersandOperator => {
                    type_ = Type::Pointer { pointed: Box::new(type_) }
                },
                Token::QuestionOperator => {
                    type_ = Type::GenericType { name: "Option".to_string(), types: vec![type_] }
                },
                Token::PipeOperator => {
                    self.next_token(TypeContext)?;
                    let type2 = self.parse_type()?;
                    type_ = Type::GenericType { name: "Result".to_string(), types: vec![type_, type2] }
                },
                Token::LeftChevronOperator => {
                    let name = match type_ {
                        Type::Type { name } => name,
                        _ => return Err(self.error(SyntaxErrorType::AtomExpected)),
                    };

                    let mut types = Vec::new();

                    self.next_token(TypeContext)?;
                    loop {
                        match self.peek_token()? {
                            Token::RightChevronOperator => break,
                            _ => {
                                types.push(self.parse_type()?);
                                
                                match self.peek_token()? {
                                    Token::RightChevronOperator => break,
                                    Token::CommaOperator => {self.next_token(TypeContext)?;},
                                    _ => return Err(self.error(SyntaxErrorType::SemicolonExpected)),
                                }
                            },
                        }
                    }

                    type_ = Type::GenericType { name, types }
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

    fn lexer(filename: &str, code: &str, start_context: ProgramContext) -> Lexer {
        let mut lexer = Lexer::new(filename.to_string(), code.to_string());
        lexer.next(start_context);
        lexer
    }

    #[test]
    fn parse_atom_int() {
        assert!(matches!(
            lexer("test.px", "2", NormalContext).parse_expression(),
            Ok(Expression::IntLiteral { value: x }) if x == 2
        ));
    }

    #[test]
    fn parse_atom_float() {
        assert!(matches!(
            lexer("test.px", "2.0", NormalContext).parse_expression(),
            Ok(Expression::FloatLiteral { value: x }) if x == 2.0
        ));
    }

    #[test]
    fn parse_atom_string() {
        assert!(matches!(
            lexer("test.px", "\"string\"", NormalContext).parse_expression(),
            Ok(Expression::StringLiteral { value: x }) if x == "string".to_string()
        ));
    }

    #[test]
    fn parse_atom_char() {
        assert!(matches!(
            lexer("test.px", "'c'", NormalContext).parse_expression(),
            Ok(Expression::CharLiteral { value: x }) if x == 'c'
        ));
    }

    #[test]
    fn parse_atom_true() {
        assert!(matches!(
            lexer("test.px", "true", NormalContext).parse_expression(),
            Ok(Expression::BooleanLiteral { value: x }) if x == true
        ));
    }

    #[test]
    fn parse_atom_false() {
        assert!(matches!(
            lexer("test.px", "false", NormalContext).parse_expression(),
            Ok(Expression::BooleanLiteral { value: x }) if x == false
        ));
    }

    #[test]
    fn parse_type_i32() {
        assert!(matches!(
            lexer("test.px", "i32", TypeContext).parse_type(),
            Ok(Type::Int32)
        ));
    }

    #[test]
    fn parse_type_i32_pointer() {
        assert!(matches!(
            lexer("test.px", "i32&", TypeContext).parse_type(),
            Ok(Type::Pointer { pointed: x }) if matches!(*x, Type::Int32)
        ));
    }

    #[test]
    fn parse_type_i32_optional() {
        assert!(matches!(
            lexer("test.px", "i32?", TypeContext).parse_type(),
            Ok(Type::GenericType { name: s, types: t }) if s == "Option".to_string() && matches!(t[0], Type::Int32)
        ));
    }

    #[test]
    fn parse_type_i32_usize_result() {
        assert!(matches!(
            lexer("test.px", "i32|usize", TypeContext).parse_type(),
            Ok(Type::GenericType { name: s, types: t }) if s == "Result".to_string() && matches!(t[0], Type::Int32) && matches!(t[1], Type::UIntSize)
        ));
    }

    #[test]
    fn parse_type_i32_array() {
        assert!(matches!(
            lexer("test.px", "[i32; 2]", TypeContext).parse_type(),
            Ok(Type::Array { type_, length }) if matches!(*type_, Type::Int32) && length == 2
        ));
    }

    #[test]
    fn parse_type_newtype() {
        assert!(matches!(
            lexer("test.px", "Test", TypeContext).parse_type(),
            Ok(Type::Type { name: s }) if s == "Test".to_string()
        ));
    }

    #[test]
    fn parse_type_newtype_generic() {
        assert!(matches!(
            lexer("test.px", "Test<i32>", TypeContext).parse_type(),
            Ok(Type::GenericType { name: s, types: t }) if s == "Test".to_string() && matches!(t[0], Type::Int32)
        ));
    }

    #[test]
    fn parse_type_newtype_generic_double() {
        assert!(matches!(
            lexer("test.px", "Test<i32, usize>", TypeContext).parse_type(),
            Ok(Type::GenericType { name: s, types: t }) if s == "Test".to_string() && matches!(t[0], Type::Int32) && matches!(t[1], Type::UIntSize)
        ));
    }

    #[test]
    fn parse_type_newtype_generic_nest() {
        assert!(matches!(
            lexer("test.px", "Test<Foo<i32>>", TypeContext).parse_type(),
            Ok(Type::GenericType { name: s, types: t }) if s == "Test".to_string() && matches!(&t[0], Type::GenericType { name: s1, types: t1 } if *s1 == "Foo".to_string() && matches!(t1[0], Type::Int32))
        ));
    }
}