mod tests;
mod read_file;

fn main() {
    let code = read_file::read_file("main.px".to_string());

    if let Err(error) = code {
        panic!("{}", error);
    }
}
