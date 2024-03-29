use crate::nodes::*;
use crate::values::*;
use crate::syntax_errors::*;
use std::collections::HashMap;

pub struct TreeWalker {
    values: Vec<HashMap<String, Value>>,
    types: Vec<HashMap<String, Type>>,
    pub output: String,
}

impl TreeWalker {
    pub fn new() -> TreeWalker {
        TreeWalker {
            values: Vec::new(),
            types: Vec::new(),
            output: String::new(),
        }
    }

    pub fn add_value(&mut self, name: String, value: Value) -> Option<()> {
        self.values.last_mut()?.insert(name, value);
        Some(())
    }

    pub fn get_value(&mut self, name: String) -> Option<&Value> {
        for scope in self.values.iter().rev() {
            let value = scope.get(&name);
            if value.is_some() { return value; }
        }
        None
    }

    pub fn add_type(&mut self, name: String, type_: Type) -> Option<()> {
        self.types.last_mut()?.insert(name, type_);
        Some(())
    }

    pub fn get_type(&mut self, name: String) -> Option<&Type> {
        for scope in self.types.iter().rev() {
            let type_ = scope.get(&name);
            if type_.is_some() { return type_; }
        }
        None
    }

    pub fn scope_in(&mut self) {
        self.values.push(HashMap::new());
        self.types.push(HashMap::new());
    }

    pub fn scope_out(&mut self) {
        self.values.pop();
        self.types.pop();
    }

    pub fn write(&mut self, string: String) {
        self.output += &string;
    }

    pub fn interpret(&mut self, tree: Result<Expression, SyntaxErrorCollector>) -> Result<Value, SyntaxErrorCollector> {
        self.interpret_expression(tree)
    }
    
    fn interpret_expression(&mut self, tree: Result<Expression, SyntaxErrorCollector>) -> Result<Value, SyntaxErrorCollector> {
        match tree {
            Ok(Expression::IntLiteral { value: x }) => Ok(Value::new(Type::IntSize, ValueData::IntegerValue(x))),
            Ok(_) => Err(SyntaxErrorCollector::new()),
            Err(x) => Err(x),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[should_panic]
    fn add_value_no_scope() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.add_value("x".to_string(), Value::new(Type::Int32, ValueData::IntegerValue(2)));

        assert!(tree_walker.values.last_mut().unwrap().contains_key(&"x".to_string()));
        assert!(matches!(tree_walker.values.last_mut().unwrap().get(&"x".to_string()).unwrap(),
            Value { type_: Type::Int32, value: ValueData::IntegerValue(2) }));
    }

    #[test]
    fn add_value_with_scope() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.scope_in();
        tree_walker.add_value("x".to_string(), Value::new(Type::Int32, ValueData::IntegerValue(2)));

        assert!(tree_walker.values.last_mut().unwrap().contains_key(&"x".to_string()));
        assert!(matches!(tree_walker.values.last_mut().unwrap().get(&"x".to_string()).unwrap(),
            Value { type_: Type::Int32, value: ValueData::IntegerValue(2) }));
    }

    #[test]
    fn get_value_single_scope() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.scope_in();
        tree_walker.add_value("x".to_string(), Value::new(Type::Int32, ValueData::IntegerValue(2)));

        assert!(matches!(tree_walker.get_value("x".to_string()),
            Some(Value { type_: Type::Int32, value: ValueData::IntegerValue(2) })));
    }

    #[test]
    fn get_value_inner_scope_same_name() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.scope_in();
        tree_walker.add_value("x".to_string(), Value::new(Type::Int32, ValueData::IntegerValue(2)));
        tree_walker.scope_in();
        tree_walker.add_value("x".to_string(), Value::new(Type::Int32, ValueData::IntegerValue(3)));

        assert!(matches!(tree_walker.get_value("x".to_string()),
            Some(Value { type_: Type::Int32, value: ValueData::IntegerValue(3) })));
    }

    #[test]
    fn get_value_outer_scope_diff_name() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.scope_in();
        tree_walker.add_value("x".to_string(), Value::new(Type::Int32, ValueData::IntegerValue(2)));
        tree_walker.scope_in();
        tree_walker.add_value("y".to_string(), Value::new(Type::Int32, ValueData::IntegerValue(3)));

        assert!(matches!(tree_walker.get_value("x".to_string()),
            Some(Value { type_: Type::Int32, value: ValueData::IntegerValue(2) })));
    }

    #[test]
    #[should_panic]
    fn add_type_no_scope() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.add_type("i32".to_string(), Type::Int32);

        assert!(tree_walker.types.last_mut().unwrap().contains_key(&"i32".to_string()));
        assert!(matches!(tree_walker.types.last_mut().unwrap().get(&"i32".to_string()).unwrap(), Type::Int32));
    }

    #[test]
    fn add_type_with_scope() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.scope_in();
        tree_walker.add_type("i32".to_string(), Type::Int32);

        assert!(tree_walker.types.last_mut().unwrap().contains_key(&"i32".to_string()));
        assert!(matches!(tree_walker.types.last_mut().unwrap().get(&"i32".to_string()).unwrap(), Type::Int32));
    }

    #[test]
    fn get_type_single_scope() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.scope_in();
        tree_walker.add_type("i32".to_string(), Type::Int32);

        assert!(matches!(tree_walker.get_type("i32".to_string()), Some(Type::Int32)));
    }

    #[test]
    fn get_type_inner_scope_same_name() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.scope_in();
        tree_walker.add_type("int".to_string(), Type::Int32);
        tree_walker.scope_in();
        tree_walker.add_type("int".to_string(), Type::Int16);

        assert!(matches!(tree_walker.get_type("int".to_string()), Some(Type::Int16)));
    }

    #[test]
    fn get_type_outer_scope_diff_name() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.scope_in();
        tree_walker.add_type("i32".to_string(), Type::Int32);
        tree_walker.scope_in();
        tree_walker.add_type("i16".to_string(), Type::Int16);

        assert!(matches!(tree_walker.get_type("i32".to_string()), Some(Type::Int32)));
    }

    #[test]
    fn write_test() {
        let mut tree_walker = TreeWalker::new();
        tree_walker.write("test\n".to_string());
        tree_walker.write("hello\n".to_string());
        assert_eq!(tree_walker.output, "test\nhello\n".to_string());
    }
}
