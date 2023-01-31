use crate::lexer::*;
use crate::nodes::*;
use crate::tokens::Token;
use crate::tokens::{TokenContext, TokenContent::*};

pub struct SyntaxErrorCollector {
    errors: Vec<SyntaxError>,
}

pub struct SyntaxError {
    error_type: SyntaxErrorType,
    context: TokenContext,
}

pub enum SyntaxErrorType {
    LexerError(LexerErrorType),
    AtomExpected,
}

impl SyntaxErrorCollector {
    fn new() -> SyntaxErrorCollector {
        SyntaxErrorCollector {
            errors: Vec::new()
        }
    }

    fn add_errors(&mut self, error_collector: SyntaxErrorCollector) {
        self.errors.extend(error_collector.errors);
    }

    fn from_error(error_type: SyntaxErrorType, context: TokenContext) -> SyntaxErrorCollector {
        let mut error_collector = Self::new();
        error_collector.errors.push(SyntaxError { error_type, context });
        error_collector
    }

    fn from_lexer_error(lexer_error: LexerError) -> SyntaxErrorCollector {
        Self::from_error(SyntaxErrorType::LexerError(lexer_error.error_type), lexer_error.context)
    }
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

    fn parse_expression(&mut self) -> Result<Expression, SyntaxErrorCollector> {
        self.parse_atom()
    }

    fn parse_atom(&mut self) -> Result<Expression, SyntaxErrorCollector> {
        match self.next(ProgramContext::NormalContext) {
            Ok(Some(Token { content: IntToken(int), context: _ })) => {
                Ok(Expression::IntLiteral { value: int })
            },
            Ok(Some(Token { content: FloatToken(float), context: _ })) => {
                Ok(Expression::FloatLiteral { value: float })
            },
            Ok(Some(Token { content: StringToken(float), context: _ })) => {
                Ok(Expression::StringLiteral { value: float })
            },
            Ok(Some(Token { content: CharToken(float), context: _ })) => {
                Ok(Expression::CharLiteral { value: float })
            },
            Ok(Some(Token { content: TrueKeyword, context: _ })) => {
                Ok(Expression::BooleanLiteral { value: true })
            },
            Ok(Some(Token { content: FalseKeyword, context: _ })) => {
                Ok(Expression::BooleanLiteral { value: false })
            },
            Ok(_) => {
                Err(SyntaxErrorCollector::from_error(SyntaxErrorType::AtomExpected, self.context.clone()))
            },
            Err(lex_error) => {
                Err(SyntaxErrorCollector::from_lexer_error(lex_error))
            },
        }
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