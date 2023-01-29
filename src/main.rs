mod read_file;
mod tokenizer;
mod tokens;

fn main() {
    let code = read_file::read_file("main.px".to_string());

    if let Err(error) = code {
        panic!("{}", error);
    }

    let mut tokenizer = tokenizer::Tokenizer::new("main.px".to_string(), "this is a test $program".to_string());

    while let Ok(Some(token)) = tokenizer.next(tokenizer::ProgramContext::NormalContext) {
        println!("{:?}", token.content);
    }
}
