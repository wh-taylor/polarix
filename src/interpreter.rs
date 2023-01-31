use crate::parser::*;
use crate::nodes::*;
use crate::values::*;

fn interpret(tree: Result<Expression, SyntaxErrorCollector>) {
    interpret_expression(tree)
}

fn interpret_expression(tree: Result<Expression, SyntaxErrorCollector>) {
    todo!();
}

#[cfg(test)]
mod tests {
    
}