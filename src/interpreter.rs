use crate::nodes::*;
use crate::values::*;
use crate::syntax_errors::*;

fn interpret(tree: Result<Expression, SyntaxErrorCollector>) -> Result<Value, SyntaxErrorCollector> {
    interpret_expression(tree)
}

fn interpret_expression(tree: Result<Expression, SyntaxErrorCollector>) -> Result<Value, SyntaxErrorCollector> {
    match tree {
        Ok(Expression::IntLiteral { value: x }) => Ok(Value::new(Type::IntSize, ValueData::IntegerValue(x))),
        Ok(_) => Err(SyntaxErrorCollector::new()),
        Err(x) => Err(x),
    }
}

#[cfg(test)]
mod tests {
    
}