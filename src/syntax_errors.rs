use crate::lexer::*;

pub struct SyntaxErrorCollector {
    errors: Vec<SyntaxError>,
}

pub struct SyntaxError {
    error_type: SyntaxErrorType,
    context: LexerContext,
}

pub enum SyntaxErrorType {
    LexerError(LexerErrorType),
    AtomExpected,
}

impl SyntaxErrorCollector {
    pub fn new() -> SyntaxErrorCollector {
        SyntaxErrorCollector {
            errors: Vec::new()
        }
    }

    pub fn add_errors(&mut self, error_collector: SyntaxErrorCollector) {
        self.errors.extend(error_collector.errors);
    }

    pub fn from_error(error_type: SyntaxErrorType, context: LexerContext) -> SyntaxErrorCollector {
        let mut error_collector = Self::new();
        error_collector.errors.push(SyntaxError { error_type, context });
        error_collector
    }

    pub fn from_lexer_error(lexer_error: LexerError) -> SyntaxErrorCollector {
        Self::from_error(SyntaxErrorType::LexerError(lexer_error.error_type), lexer_error.context)
    }
}