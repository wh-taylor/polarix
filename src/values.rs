use crate::nodes::*;

struct Value {
    type_: Type,
    value: ValueData,
}

enum ValueData {
    IntegerValue(isize),
    FloatValue(f64),
    StringValue(String),
    CharValue(char),
    BooleanValue(bool),
}

struct TreeWalker {
    values: Vec<Box<Vec<Value>>>,
    types: Vec<Box<Vec<Type>>>,
    output: String,
}

impl TreeWalker {
    fn new() -> TreeWalker {
        TreeWalker {
            values: Vec::new(),
            types: Vec::new(),
            output: String::new(),
        }
    }

    fn add_value(&mut self, value: Value) {
        self.values.last().unwrap().push(value);
    }
}
