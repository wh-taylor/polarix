use crate::nodes::*;

pub struct Value {
    pub type_: Type,
    pub value: ValueData,
}

pub enum ValueData {
    IntegerValue(isize),
    FloatValue(f64),
    StringValue(String),
    CharValue(char),
    BooleanValue(bool),
}

impl Value {
    pub fn new(type_: Type, value: ValueData) -> Value {
        Value {
            type_,
            value,
        }
    }
}
