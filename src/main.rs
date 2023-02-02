use clap::{Parser, Subcommand};
use lexer::Lexer;

mod read_file;
mod tokens;
mod lexer;
mod nodes;
mod parser;
mod static_analyzer;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[command(subcommand)]
    command: Option<Command>,

    /// Number of times to greet
    #[arg(short, long, default_value_t = 1)]
    count: u8,
}

#[derive(Subcommand, Debug)]
enum Command {
    Run {
        /// Name of the target file
        filename: String,

        /// Suppress warnings
        #[arg(long)]
        no_warnings: bool,
    }
}

fn main() {
    let args = Args::parse();
    
    match args.command {
        Some(Command::Run { filename, no_warnings }) => {
            run(filename, no_warnings)
        },
        None => {},
    }
}

fn run(filename: String, no_warnings: bool) {
    let code_result = read_file::read_file(filename.clone());
    if let Err(error) = code_result {
        println!("{}: {}", filename, error);
        return;
    }
    
    let code: String = code_result.unwrap();

    let mut lexer = Lexer::new(filename, code);
    let tree = lexer.parse_expression();
}