use crate::tokens::{Token, TokenContext, TokenContent};

const MAX_OPERATOR_LENGTH: usize = 3;

pub struct Tokenizer {
    chars: Vec<char>,
    context: TokenContext,
}

#[derive(Clone)]
pub enum ProgramContext {
    NormalContext,
    TypeContext,
}

pub struct TokenizerError {
    error_type: TokenizerErrorType,
    context: TokenContext,
}

#[derive(Clone)]
pub enum TokenizerErrorType {
    UnclosedStringError,
    UnclosedCharError,
    OverlengthyCharError,
    EmptyCharError,
    UnknownTokenStartError,
}

impl TokenizerError {
    fn new(error_type: TokenizerErrorType, context: TokenContext) -> TokenizerError {
        TokenizerError { error_type, context }
    }
}

pub type TokenizerResult = Result<Option<Token>, TokenizerError>;
type TokenizerTokenResult = Result<Option<Token>, TokenizerErrorType>;

impl Tokenizer {
    pub fn new(filename: String, code: String) -> Tokenizer {
        Tokenizer {
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

    fn contextual_token(&self, token: TokenContent) -> TokenizerTokenResult {
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

    fn lex_number(&mut self) -> TokenizerTokenResult {
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

    fn lex_string(&mut self) -> TokenizerTokenResult{
        self.next_char();
        let word = self.next_chars_until(|_, ch, _| ch == '"' || ch == '\n');

        match self.peek_char() {
            Some(ch) if ch == '"' => {
                self.next_char();
                self.contextual_token(TokenContent::StringToken(word))
            },
            _ => Err(TokenizerErrorType::UnclosedStringError),
        }
    }

    fn lex_char(&mut self) -> TokenizerTokenResult {
        self.next_char();
        let word = self.next_chars_until(|_, ch, _| ch == '\'' || ch == '\n');

        match self.peek_char() {
            Some(ch) if ch == '\'' => {
                self.next_char();
                match word.chars().collect::<Vec<char>>()[..] {
                    [c] => self.contextual_token(TokenContent::CharToken(c)),
                    [] => Err(TokenizerErrorType::EmptyCharError),
                    _ => Err(TokenizerErrorType::OverlengthyCharError),
                }
            },
            _ => Err(TokenizerErrorType::UnclosedCharError),
        }
    }

    fn lex_operator(&mut self, context: ProgramContext) -> TokenizerTokenResult {
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
        Err(TokenizerErrorType::UnknownTokenStartError)
    }

    fn lex_word(&mut self, context: ProgramContext) -> TokenizerTokenResult {
        let word = self.next_chars_until(|_, ch, _| !ch.is_alphanumeric() && ch != '_');

        match Token::string_to_token_content(word.clone(), &context) {
            Some(token_content) => self.contextual_token(token_content),
            None => self.contextual_token(TokenContent::Identifier(word))
        }
    }

    fn wrap_context(context: TokenContext, result: TokenizerTokenResult) -> TokenizerResult {
        match result {
            Ok(x) => Ok(x.clone()),
            Err(x) => Err(TokenizerError::new(x.clone(), context)),
        }
    }

    pub fn next(&mut self, program_context: ProgramContext) -> TokenizerResult {
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

    fn tokenizer(filename: &str, code: &str) -> Tokenizer {
        Tokenizer::new(filename.to_string(), code.to_string())
    }

    #[test]
    fn new_tokenizer() {
        let tokenizer = tokenizer("test.px", "test");

        assert!(matches!(
            tokenizer.chars[..],
            ['t', 'e', 's', 't']
        ));

        assert!(matches!(
            tokenizer.context,
            TokenContext { filename, index, column, line }
                if filename == "test.px".to_string()
                && index == 0
                && column == 0
                && line == 0
        ));
    }

    #[test]
    fn lex_word_main_identifier() {
        let mut tokenizer = tokenizer("test.px", "main");

        assert!(matches!(
            tokenizer.lex_word(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::Identifier(x), context: _ }))
                if x == "main".to_string()
        ));
    }

    #[test]
    fn lex_operator_plus() {
        let mut tokenizer = tokenizer("test.px", "+");

        assert!(matches!(
            tokenizer.lex_operator(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::PlusOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_operator_plus_equal() {
        let mut tokenizer = tokenizer("test.px", "+=");

        assert!(matches!(
            tokenizer.lex_operator(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::PlusEqualOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_operator_one_gt() {
        let mut tokenizer = tokenizer("test.px", ">");

        assert!(matches!(
            tokenizer.lex_operator(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::RightChevronOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_operator_two_gt_normal() {
        let mut tokenizer = tokenizer("test.px", ">>");

        assert!(matches!(
            tokenizer.lex_operator(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::DoubleRightChevronOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_operator_two_gt_type() {
        let mut tokenizer = tokenizer("test.px", ">>");

        assert!(matches!(
            tokenizer.lex_operator(ProgramContext::TypeContext),
            Ok(Some(Token { content: TokenContent::RightChevronOperator, context: _ }))
        ));

        assert!(matches!(
            tokenizer.lex_operator(ProgramContext::TypeContext),
            Ok(Some(Token { content: TokenContent::RightChevronOperator, context: _ }))
        ));
    }


    #[test]
    fn lex_number_integer_42() {
        let mut tokenizer = tokenizer("test.px", "42");

        assert!(matches!(
            tokenizer.lex_number(),
            Ok(Some(Token { content: TokenContent::IntToken(x), context: _ }))
                if x == 42
        ));
    }

    #[test]
    fn lex_number_float_42() {
        let mut tokenizer = tokenizer("test.px", "42.0");

        assert!(matches!(
            tokenizer.lex_number(),
            Ok(Some(Token { content: TokenContent::FloatToken(x), context: _ }))
                if x == 42.0
        ));
    }

    #[test]
    fn lex_int_then_dot() {
        let mut tokenizer = tokenizer("test.px", "42.");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::IntToken(x), context: _ }))
                if x == 42
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::DotOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_int_then_field() {
        let mut tokenizer = tokenizer("test.px", "42.a");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::IntToken(x), context: _ }))
                if x == 42
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::DotOperator, context: _ }))
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::Identifier(x), context: _ }))
                if x == "a".to_string()
        ));
    }

    #[test]
    fn lex_float_then_dot() {
        let mut tokenizer = tokenizer("test.px", "42.0.");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::FloatToken(x), context: _ }))
                if x == 42.0
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::DotOperator, context: _ }))
        ));
    }

    #[test]
    fn lex_float_then_field() {
        let mut tokenizer = tokenizer("test.px", "42.0.a");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::FloatToken(x), context: _ }))
                if x == 42.0
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::DotOperator, context: _ }))
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::Identifier(x), context: _ }))
                if x == "a".to_string()
        ));
    }

    #[test]
    fn lex_word_keyword() {
        let mut tokenizer = tokenizer("test.px", "let");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::LetKeyword, context: _ }))
        ));
    }

    #[test]
    fn lex_word_keyword_type() {
        let mut tokenizer = tokenizer("test.px", "i32");

        assert!(matches!(
            tokenizer.next(ProgramContext::TypeContext),
            Ok(Some(Token { content: TokenContent::I32Keyword, context: _ }))
        ));
    }

    #[test]
    fn lex_operator_unknown_start() {
        let mut tokenizer = tokenizer("test.px", "$$ let");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Err(TokenizerError {
                error_type: TokenizerErrorType::UnknownTokenStartError,
                context: _,
            })
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::LetKeyword, context: _ }))
        ));
    }

    #[test]
    fn lex_string() {
        let mut tokenizer = tokenizer("test.px", "\"string\" \"string2\"");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::StringToken(x), context: _ }))
                if x == "string".to_string()
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::StringToken(x), context: _ }))
                if x == "string2".to_string()
        ));
    }

    #[test]
    fn lex_string_unclosed_eol() {
        let mut tokenizer = tokenizer("test.px", "\"string");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Err(TokenizerError {
                error_type: TokenizerErrorType::UnclosedStringError,
                context: _,
            })
        ));
    }

    #[test]
    fn lex_string_unclosed_newline() {
        let mut tokenizer = tokenizer("test.px", "\"string\nlet");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Err(TokenizerError {
                error_type: TokenizerErrorType::UnclosedStringError,
                context: _,
            })
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::LetKeyword, context: _ }))
        ));
    }

    #[test]
    fn lex_char() {
        let mut tokenizer = tokenizer("test.px", "'c' 'd'");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::CharToken(x), context: _ }))
                if x == 'c'
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::CharToken(x), context: _ }))
                if x == 'd'
        ));
    }

    #[test]
    fn lex_char_unclosed_eol() {
        let mut tokenizer = tokenizer("test.px", "'c");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Err(TokenizerError {
                error_type: TokenizerErrorType::UnclosedCharError,
                context: _,
            })
        ));
    }

    #[test]
    fn lex_char_unclosed_newline() {
        let mut tokenizer = tokenizer("test.px", "'c\nlet");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Err(TokenizerError {
                error_type: TokenizerErrorType::UnclosedCharError,
                context: _,
            })
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::LetKeyword, context: _ }))
        ));
    }

    #[test]
    fn lex_char_overlengthy() {
        let mut tokenizer = tokenizer("test.px", "'ch'let");

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Err(TokenizerError {
                error_type: TokenizerErrorType::OverlengthyCharError,
                context: _,
            })
        ));

        assert!(matches!(
            tokenizer.next(ProgramContext::NormalContext),
            Ok(Some(Token { content: TokenContent::LetKeyword, context: _ }))
        ));
    }
}
