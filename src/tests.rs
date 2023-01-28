#[cfg(test)]
mod tests {
    use crate::read_file::*;

    #[test]
    fn test_read_file() {
        let filename = "main.px";
        match read_file(filename.to_string()) {
            Ok(text) => assert_eq!(text, "a"),
            Err(_)           => panic!("file {} not found", filename),
        }
    }
}