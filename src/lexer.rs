use crate::tokens::{Token, TokenContext, TokenContent};

const MAX_OPERATOR_LENGTH: usize = 3;

pub struct Lexer {
    chars: Vec<char>,
    context: TokenContext,
}

#[derive(Clone)]
pub enum ProgramContext {
    NormalContext,
    TypeContext,
}

pub struct LexerError {
    error_type: LexerErrorType,
    context: TokenContext,
}

#[derive(Clone)]
pub enum LexerErrorType {
    UnclosedStringError,
    UnclosedCharError,
    OverlengthyCharError,
    EmptyCharError,
    UnknownTokenStartError,
}

impl LexerError {
    fn new(error_type: LexerErrorType, context: TokenContext) -> LexerError {
        LexerError { error_type, context }
    }
}

pub type LexerResult = Result<Option<Token>, LexerError>;
type LexerTokenResult = Result<Option<Token>, LexerErrorType>;

impl Lexer {
    pub fn new(filename: String, code: String) -> Lexer {
        Lexer {
            chars: code.chars().collect(),
            context: TokenContext {
                filename,
                index: 0,
                column: 0,
                line: 0,
            }
        }
    }

    fn peek_char(&self) -> Option<char> {
        self.peek_chars(0)
    }

    fn peek_chars(&self, forward: usize) -> Option<char> {
        match self.chars.get(self.context.index + forward) {
            Some(&ch) => Some(ch),
            _         => None,
        }
    }

    fn next_char(&mut self) -> Option<char> {
        let current_char: Option<char> = self.peek_char();

        if let Some(ch) = current_char {
            if ch == '\n' {
                self.context.line += 1;
                self.context.column = 0;
            }

            self.context.column += 1;
            self.context.index += 1;

            Some(ch)
        } else {
            None
        }
    }

    fn next_chars(&mut self, forward: usize) -> Option<char> {
        for _ in 0..forward {
            self.next_char();
        }
        self.next_char()
    }

    fn contextual_token(&self, token: TokenContent) -> LexerTokenResult {
        Ok(Some(Token::new(token, self.context.clone())))
    }

    fn next_chars_until(&mut self, f: impl Fn(&String, char, Option<char>) -> bool) -> String {
        let mut word: String = String::new();

        while let Some(ch) = self.peek_char() {
            if f(&word, ch, self.peek_chars(1)) {
                break;
            }
            word.push(ch);
            self.next_char();
        }

        word
    }

    fn lex_number(&mut self) -> LexerTokenResult {
        let word = self.next_chars_until(|w, ch, next| {
            !ch.is_numeric() && ch != '_' && ch != '.'
                || ch == '.' && w.contains('.')
                || ch == '.' && !matches!(next, Some(x) if x.is_numeric() || x == '_' || x == '.')
        });

        if word.contains('.') {
            self.contextual_token(TokenContent::FloatToken(word.parse::<f64>().unwrap()))
        } else {
            self.contextual_token(TokenContent::IntToken(word.parse::<isize>().unwrap()))
        }
    }

    fn lex_string(&mut self) -> LexerTokenResult{
        self.next_char();
        let word = self.next_chars_until(|_, ch, _| ch == '"' || ch == '\n');

        match self.peek_char() {
            Some(ch) if ch == '"' => {
                self.next_char();
                self.contextual_token(TokenContent::StringToken(word))
            },
            _ => Err(LexerErrorType::UnclosedStringError),
        }
    }

    fn lex_char(&mut self) -> LexerTokenResult {
        self.next_char();
        let word = self.next_chars_until(|_, ch, _| ch == '\'' || ch == '\n');

        match self.peek_char() {
            Some(ch) if ch == '\'' => {
                self.next_char();
                match word.chars().collect::<Vec<char>>()[..] {
                    [c] => self.contextual_token(TokenContent::CharToken(c)),
                    [] => Err(LexerErrorType::EmptyCharError),
                    _ => Err(LexerErrorType::OverlengthyCharError),
                }
            },
            _ => Err(LexerErrorType::UnclosedCharError),
        }
    }

    fn lex_operator(&mut self, context: ProgramContext) -> LexerTokenResult {
        for length in (1..=MAX_OPERATOR_LENGTH).rev() {
            let operator = self.chars.get(self.context.index..self.context.index + length);
            if let None = operator { continue; }

            let token_content = Token::string_to_token_content(operator.unwrap().iter().collect(), &context);
            if let None = token_content { continue; }

            self.next_chars(length - 1);
            return self.contextual_token(token_content.unwrap());
        }

        while matches!(self.peek_char(), Some(ch) if ch.is_ascii_punctuation()) {
            self.next_char();
        }
        Err(LexerErrorType::UnknownTokenStartError)
    }

    fn lex_word(&mut self, context: ProgramContext) -> LexerTokenResult {
        let word = self.next_chars_until(|_, ch, _| !ch.is_alphanumeric() && ch != '_');

        match Token::string_to_token_content(word.clone(), &context) {
            Some(token_content) => self.contextual_token(token_content),
            None => self.contextual_token(TokenContent::Identifier(word))
        }
    }

    fn wrap_context(context: TokenContext, result: LexerTokenResult) -> LexerResult {
        match result {
            Ok(x) => Ok(x.clone()),
            Err(x) => Err(LexerError::new(x.clone(), context)),
        }
    }

    pub fn next(&mut self, program_context: ProgramContext) -> LexerResult {
        // Skip whitespace
        while match self.peek_char() {
            Some(ch) => ch.is_whitespace(),
            None => { return Ok(None); },
        } {
            self.next_char();
        }
        // Get next token
        let context = self.context.clone();

        let result = match self.peek_char() {
            Some(x) if x.is_digit(10)    => self.lex_number(),
            Some(x) if x == '"'          => self.lex_string(),
            Some(x) if x == '\''         => self.lex_char(),
            Some(x) if
                x.is_alphabetic()
                || x == '_'              => self.lex_word(program_context),
            Some(_)                      => self.lex_operator(program_context),
            None                         => Ok(None),
        };

        Self::wrap_context(context, result)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lexer(filename: &str, code: &str) -> Lexer {
        Lexer::new(filename.to_string(), code.to_string())
    }

    #[test]
    fn new_lexer() {
        let lexer = lexer("test.px", "test");

        assert!(matches!(
            lexer.chars[..],
            ['t', 'e', 's', 't']
        ));

        assert!(matches!(
            lexer.context,
            TokenContext { filename, index, column, line }
                if filename == "test.px".to_string()
                && index == 0
                && column == 0
                && line == 0
        ));
    }

    #[test]
    fn lex_word_main_identifier() {
        let mut lexer = lexer("test.px", "main");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::Identifier(x), context: _ }))
                if x == "main".to_string()
        ));
    }

    #[test]
    fn lex_operator_plus() {
        let mut lexer = lexer("test.px", "+");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::PlusOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_operator_plus_equal() {
        let mut lexer = lexer("test.px", "+=");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::PlusEqualOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_operator_one_gt() {
        let mut lexer = lexer("test.px", ">");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::RightChevronOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_operator_two_gt_normal() {
        let mut lexer = lexer("test.px", ">>");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::DoubleRightChevronOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_operator_two_gt_type() {
        let mut lexer = lexer("test.px", ">>");

        assert!(matches!(
            lexer.next(ProgramContext::TypeContext),
            Ok(Some(Token { content: TokenContent::RightChevronOperator, context: _ }))
        ));

        assert!(matches!(
            lexer.next(ProgramContext::TypeContext),
            Ok(Some(Token { content: TokenContent::RightChevronOperator, context: _ }))
        ));
    }


    #[test]
    fn lex_number_integer_42() {
        let mut lexer = lexer("test.px", "42");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::IntToken(x), context: _ }))
                if x == 42
        ));
    }

    #[test]
    fn lex_number_float_42() {
        let mut lexer = lexer("test.px", "42.0");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::FloatToken(x), context: _ }))
                if x == 42.0
        ));
    }

    #[test]
    fn lex_int_then_dot() {
        let mut lexer = lexer("test.px", "42.");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::IntToken(x), context: _ }))
                if x == 42
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::DotOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_int_then_field() {
        let mut lexer = lexer("test.px", "42.a");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::IntToken(x), context: _ }))
                if x == 42
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::DotOperator, context: _ }))
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::Identifier(x), context: _ }))
                if x == "a".to_string()
        ));
    }

    #[test]
    fn lex_float_then_dot() {
        let mut lexer = lexer("test.px", "42.0.");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::FloatToken(x), context: _ }))
                if x == 42.0
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::DotOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_float_then_field() {
        let mut lexer = lexer("test.px", "42.0.a");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::FloatToken(x), context: _ }))
                if x == 42.0
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::DotOperator, context: _ }))
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::Identifier(x), context: _ }))
                if x == "a".to_string()
        ));
    }

    #[test]
    fn lex_word_keyword() {
        let mut lexer = lexer("test.px", "let");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::LetKeyword, context: _ }))
        ));
    }

    #[test]
    fn lex_word_keyword_type() {
        let mut lexer = lexer("test.px", "i32");

        assert!(matches!(
            lexer.next(ProgramContext::TypeContext),
            Ok(Some(Token { content: TokenContent::I32Keyword, context: _ }))
        ));
    }

    #[test]
    fn lex_operator_unknown_start() {
        let mut lexer = lexer("test.px", "$$ let");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Err(LexerError {
                error_type: LexerErrorType::UnknownTokenStartError,
                context: _,
            })
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::LetKeyword, context: _ }))
        ));
    }

    #[test]
    fn lex_string() {
        let mut lexer = lexer("test.px", "\"string\"\"string2\"");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::StringToken(x), context: _ }))
                if x == "string".to_string()
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::StringToken(x), context: _ }))
                if x == "string2".to_string()
        ));
    }

    #[test]
    fn lex_string_unclosed_eol() {
        let mut lexer = lexer("test.px", "\"string");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Err(LexerError {
                error_type: LexerErrorType::UnclosedStringError,
                context: _,
            })
        ));
    }

    #[test]
    fn lex_string_unclosed_newline() {
        let mut lexer = lexer("test.px", "\"string\nlet");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Err(LexerError {
                error_type: LexerErrorType::UnclosedStringError,
                context: _,
            })
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::LetKeyword, context: _ }))
        ));
    }

    #[test]
    fn lex_char() {
        let mut lexer = lexer("test.px", "'c''d'");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::CharToken(x), context: _ }))
                if x == 'c'
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::CharToken(x), context: _ }))
                if x == 'd'
        ));
    }

    #[test]
    fn lex_char_unclosed_eol() {
        let mut lexer = lexer("test.px", "'c");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Err(LexerError {
                error_type: LexerErrorType::UnclosedCharError,
                context: _,
            })
        ));
    }

    #[test]
    fn lex_char_unclosed_newline() {
        let mut lexer = lexer("test.px", "'c\nlet");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Err(LexerError {
                error_type: LexerErrorType::UnclosedCharError,
                context: _,
            })
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::LetKeyword, context: _ }))
        ));
    }

    #[test]
    fn lex_char_overlengthy() {
        let mut lexer = lexer("test.px", "'ch'let");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Err(LexerError {
                error_type: LexerErrorType::OverlengthyCharError,
                context: _,
            })
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::LetKeyword, context: _ }))
        ));
    }
}
