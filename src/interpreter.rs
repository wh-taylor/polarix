use crate::parser::*;
use crate::nodes::*;
use crate::values::*;

fn interpret(tree: Result<Expression, SyntaxError>) {
    interpret_expression(tree)
}

fn interpret_expression(tree: Result<Expression, SyntaxError>) {
    match tree {
        
    }
}

#[cfg(test)]
mod tests {
    
}