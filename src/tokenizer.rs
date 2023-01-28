use std::{str::Chars, iter::Peekable};
use crate::tokens::{Token, TokenContext, TokenContent};

pub struct Tokenizer {
    chars: Peekable<Chars<'static>>,
    context: TokenContext,
}

pub enum ProgramContext {
    NormalContext,
    TypeContext,
}

impl Tokenizer {
    pub fn new(filename: String, code: &'static str) -> Tokenizer {
        Tokenizer {
            chars: code.chars().peekable(),
            context: TokenContext {
                filename,
                index: 0,
                column: 0,
                line: 0,
            }
        }
    }

    fn next_char(&mut self) -> Option<char> {
        let current_char: Option<char> = self.chars.next();

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

    fn contextual_token(&self, token: TokenContent) -> Option<Token> {
        Some(
            Token {
                content: token,
                context: self.context.clone(),
            }
        )
    }

    fn next_chars_until(&mut self, f: impl Fn(&String, char, Option<&char>) -> bool) -> String {
        let mut word: String = String::new();

        while let Some(next_char) = self.chars.next() {
            println!("{}", next_char);
            if f(&word, next_char, self.chars.peek()) {
                break;
            }
            word.push(next_char);
        }

        word
    }

    fn lex_number(&mut self) -> Option<Token> {
        let word = self.next_chars_until(|w, ch, next| {
            !ch.is_numeric() && ch != '_' && ch != '.'
                || ch == '.' && w.contains('.')
                || ch == '.' && matches!(next, Some(x) if !x.is_numeric() && *x != '_' && *x != '.')
        });
        
        if word.contains('.') {
            self.contextual_token(TokenContent::FloatToken(word.parse::<f64>().unwrap()))
        } else {
            self.contextual_token(TokenContent::IntToken(word.parse::<isize>().unwrap()))
        }
    }

    fn lex_string(&mut self) -> Option<Token> {
        self.next_char();
        let word = self.next_chars_until(|_, ch, _| ch == '"');

        self.contextual_token(TokenContent::StringToken(word))
    }

    fn lex_char(&mut self) -> Option<Token> {
        self.next_char();
        let word = self.next_chars_until(|_, ch, _| ch == '\'');

        self.contextual_token(TokenContent::CharToken(word.chars().nth(0).unwrap()))
    }

    fn lex_operator(&mut self, context: ProgramContext) -> Option<Token> {
        self.contextual_token(TokenContent::PlusOperator)
    }

    fn lex_word(&mut self) -> Option<Token> {
        let word = self.next_chars_until(|_, ch, _| !ch.is_alphanumeric() && ch != '_');

        // if a keyword is identified, return the corresponding keyword token

        self.contextual_token(TokenContent::Identifier(word))
    }

    pub fn next(&mut self, context: ProgramContext) -> Option<Token> {
        // Get next token
        match self.chars.peek() {
            Some(x) if x.is_whitespace() => { self.next_char(); self.next(context) },
            Some(x) if x.is_digit(10)    => self.lex_number(),
            Some(x) if *x == '"'         => self.lex_string(),
            Some(x) if *x == '\''        => self.lex_char(),
            Some(x) if
                x.is_alphabetic()
                || *x == '_'             => self.lex_word(),
            Some(_)                      => self.lex_operator(context),
            None                         => None,
        }
    }
}