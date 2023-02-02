use crate::lexer::*;
use crate::nodes::*;
use crate::tokens::Token;

pub struct SyntaxError {
    pub error_type: SyntaxErrorType,
    pub context: LexerContext,
}

pub enum SyntaxErrorType {
    LexerError(LexerErrorType),
    AtomExpected,
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

    pub fn parse_expression(&mut self) -> Result<Expression, Vec<SyntaxError>> {
        self.parse_atom()
    }

    fn parse_atom(&mut self) -> Result<Expression, Vec<SyntaxError>> {
        match self.next_token(ProgramContext::NormalContext)? {
            Token::IntToken(int)         => Ok(Expression::IntLiteral { value: int }),
            Token::FloatToken(float)     => Ok(Expression::FloatLiteral { value: float }),
            Token::StringToken(float)    => Ok(Expression::StringLiteral { value: float }),
            Token::CharToken(float)      => Ok(Expression::CharLiteral { value: float }),
            Token::TrueKeyword           => Ok(Expression::BooleanLiteral { value: true }),
            Token::FalseKeyword          => Ok(Expression::BooleanLiteral { value: false }),
            _                            => Err(self.error(SyntaxErrorType::AtomExpected)),
        }
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