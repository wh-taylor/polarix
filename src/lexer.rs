use crate::tokens::Token;
use LexerErrorType::*;

const MAX_OPERATOR_LENGTH: usize = 3;

pub struct Lexer {
    chars: Vec<char>,
    last_token: Result<Token, LexerError>,
    pub context: LexerContext,
}

#[derive(Clone, Debug)]
pub struct LexerContext {
    pub filename: String,
    pub index: usize,
    pub column: usize,
    pub line: usize,
}

#[derive(Clone)]
pub enum ProgramContext {
    NormalContext,
    TypeContext,
}

#[derive(Clone, Debug)]
pub struct LexerError {
    pub error_type: LexerErrorType,
    pub context: LexerContext,
}

#[derive(Clone, Debug)]
pub enum LexerErrorType {
    UnclosedStringError,
    UnclosedCharError,
    OverlengthyCharError,
    EmptyCharError,
    UnknownTokenStartError,
}

impl LexerError {
    fn new(error_type: LexerErrorType, context: LexerContext) -> LexerError {
        LexerError { error_type, context }
    }
}

impl Lexer {
    pub fn new(filename: String, code: String) -> Lexer {
        Lexer {
            chars: code.chars().collect(),
            last_token: Ok(Token::BOF),
            context: LexerContext {
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

    // fn contextual_token(&self, token: Token) -> LexerTokenResult {
    //     Ok(Some(Token::new(token, self.context.clone())))
    // }

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

    fn lex_number(&mut self) -> Result<Token, LexerError> {
        let word = self.next_chars_until(|w, ch, next| {
            !ch.is_numeric() && ch != '_' && ch != '.'
                || ch == '.' && w.contains('.')
                || ch == '.' && !matches!(next, Some(x) if x.is_numeric() || x == '_' || x == '.')
        });

        if word.contains('.') {
            Ok(Token::FloatToken(word.parse::<f64>().unwrap()))
        } else {
            Ok(Token::IntToken(word.parse::<isize>().unwrap()))
        }
    }

    fn lex_string(&mut self) -> Result<Token, LexerError> {
        let context = self.context.clone();

        self.next_char();
        let word = self.next_chars_until(|_, ch, _| ch == '"' || ch == '\n');

        match self.peek_char() {
            Some(ch) if ch == '"' => {
                self.next_char();
                Ok(Token::StringToken(word))
            },
            _ => Err(LexerError::new(UnclosedStringError, context)),
        }
    }

    fn lex_char(&mut self) -> Result<Token, LexerError> {
        let context = self.context.clone();

        self.next_char();
        let word = self.next_chars_until(|_, ch, _| ch == '\'' || ch == '\n');

        match self.peek_char() {
            Some(ch) if ch == '\'' => {
                self.next_char();
                match word.chars().collect::<Vec<char>>()[..] {
                    [c] => Ok(Token::CharToken(c)),
                    [] => Err(LexerError::new(EmptyCharError, context)),
                    _ => Err(LexerError::new(OverlengthyCharError, context)),
                }
            },
            _ => Err(LexerError::new(UnclosedCharError, context)),
        }
    }

    fn lex_operator(&mut self, program_context: ProgramContext) -> Result<Token, LexerError> {
        let context = self.context.clone();

        for length in (1..=MAX_OPERATOR_LENGTH).rev() {
            let operator = self.chars.get(self.context.index..self.context.index + length);
            if let None = operator { continue; }

            let token_content = Token::string_to_token_content(operator.unwrap().iter().collect(), &program_context);
            if let None = token_content { continue; }

            self.next_chars(length - 1);
            return Ok(token_content.unwrap());
        }

        while matches!(self.peek_char(), Some(ch) if ch.is_ascii_punctuation()) {
            self.next_char();
        }
        Err(LexerError::new(UnknownTokenStartError, context))
    }

    fn lex_word(&mut self, program_context: ProgramContext) -> Result<Token, LexerError> {
        let word = self.next_chars_until(|_, ch, _| !ch.is_alphanumeric() && ch != '_');

        match Token::string_to_token_content(word.clone(), &program_context) {
            Some(token_content) => Ok(token_content),
            None => Ok(Token::Identifier(word))
        }
    }

    pub fn next(&mut self, program_context: ProgramContext) -> Result<Token, LexerError> {
        // Skip whitespace
        while match self.peek_char() {
            Some(ch) => ch.is_whitespace(),
            None => { return Ok(Token::EOF); },
        } {
            self.next_char();
        }
        // Get next token
        let result = match self.peek_char() {
            Some(x) if x.is_digit(10)    => self.lex_number(),
            Some(x) if x == '"'          => self.lex_string(),
            Some(x) if x == '\''         => self.lex_char(),
            Some(x) if
                x.is_alphabetic()
                || x == '_'              => self.lex_word(program_context),
            Some(_)                      => self.lex_operator(program_context),
            None                         => Ok(Token::EOF),
        };

        self.last_token = result.clone();

        result
    }

    pub fn peek(&self) -> Result<Token, LexerError> {
        self.last_token.clone()
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
            LexerContext { filename, index, column, line }
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
            Ok(Token::Identifier(x))
                if x == "main".to_string()
        ));
    }

    #[test]
    fn lex_operator_plus() {
        let mut lexer = lexer("test.px", "+");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::PlusOperator)
        ));
    }

    #[test]
    fn lex_operator_plus_equal() {
        let mut lexer = lexer("test.px", "+=");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::PlusEqualOperator),
        ));
    }

    #[test]
    fn lex_operator_one_gt() {
        let mut lexer = lexer("test.px", ">");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::RightChevronOperator)
        ));
    }

    #[test]
    fn lex_operator_two_gt_normal() {
        let mut lexer = lexer("test.px", ">>");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::DoubleRightChevronOperator)
        ));
    }

    #[test]
    fn lex_operator_two_gt_type() {
        let mut lexer = lexer("test.px", ">>");

        assert!(matches!(
            lexer.next(ProgramContext::TypeContext),
            Ok(Token::RightChevronOperator)
        ));

        assert!(matches!(
            lexer.next(ProgramContext::TypeContext),
            Ok(Token::RightChevronOperator)
        ));
    }


    #[test]
    fn lex_number_integer_42() {
        let mut lexer = lexer("test.px", "42");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::IntToken(x))
                if x == 42
        ));
    }

    #[test]
    fn lex_number_float_42() {
        let mut lexer = lexer("test.px", "42.0");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::FloatToken(x))
                if x == 42.0
        ));
    }

    #[test]
    fn lex_int_then_dot() {
        let mut lexer = lexer("test.px", "42.");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::IntToken(x))
                if x == 42
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::DotOperator)
        ));
    }

    #[test]
    fn lex_int_then_field() {
        let mut lexer = lexer("test.px", "42.a");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::IntToken(x))
                if x == 42
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::DotOperator)
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::Identifier(x))
                if x == "a".to_string()
        ));
    }

    #[test]
    fn lex_float_then_dot() {
        let mut lexer = lexer("test.px", "42.0.");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::FloatToken(x))
                if x == 42.0
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::DotOperator)
        ));
    }

    #[test]
    fn lex_float_then_field() {
        let mut lexer = lexer("test.px", "42.0.a");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::FloatToken(x))
                if x == 42.0
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::DotOperator)
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::Identifier(x))
                if x == "a".to_string()
        ));
    }

    #[test]
    fn lex_word_keyword() {
        let mut lexer = lexer("test.px", "let");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::LetKeyword)
        ));
    }

    #[test]
    fn lex_word_keyword_type() {
        let mut lexer = lexer("test.px", "i32");

        assert!(matches!(
            lexer.next(ProgramContext::TypeContext),
            Ok(Token::I32Keyword)
        ));
    }

    #[test]
    fn lex_operator_unknown_start() {
        let mut lexer = lexer("test.px", "$$ let");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Err(LexerError {
                error_type: UnknownTokenStartError,
                context: _,
            })
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::LetKeyword)
        ));
    }

    #[test]
    fn lex_string() {
        let mut lexer = lexer("test.px", "\"string\"\"string2\"");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::StringToken(x))
                if x == "string".to_string()
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::StringToken(x))
                if x == "string2".to_string()
        ));
    }

    #[test]
    fn lex_string_unclosed_eol() {
        let mut lexer = lexer("test.px", "\"string");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Err(LexerError {
                error_type: UnclosedStringError,
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
                error_type: UnclosedStringError,
                context: _,
            })
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::LetKeyword)
        ));
    }

    #[test]
    fn lex_char() {
        let mut lexer = lexer("test.px", "'c''d'");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::CharToken(x))
                if x == 'c'
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::CharToken(x))
                if x == 'd'
        ));
    }

    #[test]
    fn lex_char_unclosed_eol() {
        let mut lexer = lexer("test.px", "'c");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Err(LexerError {
                error_type: UnclosedCharError,
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
                error_type: UnclosedCharError,
                context: _,
            })
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::LetKeyword)
        ));
    }

    #[test]
    fn lex_char_overlengthy() {
        let mut lexer = lexer("test.px", "'ch'let");

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Err(LexerError {
                error_type: OverlengthyCharError,
                context: _,
            })
        ));

        assert!(matches!(
            lexer.next(ProgramContext::NormalContext),
            Ok(Token::LetKeyword)
        ));
    }
}
