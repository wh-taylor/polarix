mod read_file;
mod lexer;
mod tokens;

fn main() {
    let code = read_file::read_file("main.px".to_string());

    if let Err(error) = code {
        panic!("{}", error);
    }

    let mut lexer = lexer::Lexer::new("main.px".to_string(), "this is a test $program".to_string());

    while let Ok(Some(token)) = lexer.next(lexer::ProgramContext::NormalContext) {
        println!("{:?}", token.content);
    }
}
