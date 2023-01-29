#[cfg(test)]
mod tests {
    use crate::read_file;

    #[test]
    fn test_read_file() {
        let filename = "main.px";
        match read_file::read_file(filename.to_string()) {
            Ok(text) => assert_eq!(text, "a"),
            Err(_)           => panic!("file {} not found", filename),
        }
    }

    // Tokenizer tests
    use crate::tokenizer::{Tokenizer, ProgramContext, TokenizerResult};

    fn tokenizer(filename: &str, code: &str) -> Tokenizer {
        Tokenizer::new(filename.to_string(), code.to_string())
    }

    fn run_tokenizer(filename: &str, code: &str, program_context: ProgramContext) -> Vec<TokenizerResult> {
        let mut tokenizer = self::tokenizer(filename, code);
        let mut vec: Vec<TokenizerResult> = Vec::new();
        loop {
            match tokenizer.next(program_context.clone()) {
                Ok(None) => break,
                x => vec.push(x),
            }
        }
        vec
    }
}