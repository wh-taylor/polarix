use std::fs::File;
use std::io::Error;
use std::io::prelude::*;

pub fn read_file(filename: String) -> Result<String, Error> {
    match File::open(filename) {
        Ok(mut file) => get_file_contents(&mut file),
        Err(error) => Err(error),
    }
}

fn get_file_contents(file: &mut File) -> Result<String, Error> {
    let mut contents = String::new();
    match file.read_to_string(&mut contents) {
        Ok(_) => Ok(contents),
        Err(error) => Err(error),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn read_file_test() {
        let filename = "main.px";
        match read_file(filename.to_string()) {
            Ok(text) => assert_eq!(text, "a"),
            Err(_)           => panic!("file {} not found", filename),
        }
    }
}