#[derive(Debug)]
pub enum Item {
    Import {
        imported: String,
    },
    Use {
        used: String,
    },
    Function {
        header: FunctionHeader,
        body: Block,
    },
    Struct {
        name: String,
        type_parameters: Vec<String>,
        fields: Vec<StructField>,
    },
    Enum {
        name: String,
        type_parameters: Vec<String>,
        fields: Vec<EnumField>,
    },
    Trait {
        name: String,
        type_parameters: Vec<String>,
        items: Vec<Item>,
    },
    Instance {
        trait_: Trait,
        type_: Type,
        items: Vec<Item>,
    },
    TypeAlias {
        newtype: String,
        oldtype: Type,
    },
    ConstItem {
        name: String,
        type_: Type,
        value: Expression,
    },
}

#[derive(Debug)]
pub struct FunctionHeader {
    pub name: String,
    pub parameters: Vec<String>,
    pub types: Vec<Type>,
    pub return_type: Type,
}

#[derive(Debug)]
pub struct StructField {
    name: String,
    type_: Type,
}

#[derive(Debug)]
pub struct EnumField {
    name: String,
    types: Vec<Type>,
}

// Expression nodes

#[derive(Debug)]
pub enum Expression {
    ForExpression {
        pattern: Pattern,
        iterator: Box<Expression>,
        body: Block,
    },
    IfExpression {
        condition: Box<Expression>,
        body: Block,
        alternate: Block,
    },
    WhileExpression {
        condition: Box<Expression>,
        body: Block,
    },
    LoopExpression {
        body: Block,
    },
    MatchExpression {
        discriminant: Box<Expression>,
        branches: Vec<MatchBranch>,
    },
    BlockExpression {
        body: Block,
    },
    TryExpression {
        expression: Box<Expression>,
    },
    CatchExpression {
        expression: Box<Expression>,
        result: Box<Expression>,
    },
    ArrayExpression {
        type_: Type,
        elements: Vec<Expression>,
    },
    CallExpression {
        callee: Box<Expression>,
        arguments: Vec<Expression>,
    },
    IndexExpression {
        indexed: Box<Expression>,
        argument: Box<Expression>,
    },
    FieldExpression {
        left: Box<Expression>,
        right: String,
    },
    TypeCastExpression {
        value: Box<Expression>,
        type_: Type,
    },
    ReturnExpression {
        returned: Option<Box<Expression>>,
    },
    BreakExpression {
        returned: Option<Box<Expression>>,
    },
    ContinueExpression,
    StructExpression {
        struct_: String,
        fields: Vec<StructExpressionField>,
    },
    PathExpression {
        source: PathSegment,
        member: PathSegment,
    },
    BinaryOp {
        op: Operator,
        left: Box<Expression>,
        right: Box<Expression>,
    },
    UnaryOp {
        op: Operator,
        child: Box<Expression>,
    },
    Variable {
        name: String,
    },
    IntLiteral {
        value: isize,
    },
    FloatLiteral {
        value: f64,
    },
    StringLiteral {
        value: String,
    },
    CharLiteral {
        value: char,
    },
    BooleanLiteral {
        value: bool,
    },
}

#[derive(Debug)]
pub struct Block {
    pub statements: Vec<Statement>,
    pub expression: Option<Box<Expression>>,
}

#[derive(Debug)]
pub struct MatchBranch {
    pattern: Pattern,
    consequent: Expression,
}

#[derive(Debug)]
pub struct StructExpressionField {
    name: String,
    expression: Expression,
}

#[derive(Debug)]
pub struct Pattern {

}

#[derive(Debug)]
pub enum Operator {
    AddOperator,
    SubtractOperator,
    MultiplyOperator,
    DivideOperator,
    ModuloOperator,
    NegateOperator,
}

#[derive(Debug)]
pub enum PathSegment {
    PathIdentifier {
        id: String
    },
    SuperPath,
    SelfPath,
}

// Statement nodes

#[derive(Debug)]
pub enum Statement {
    LetStatement {
        pattern: Pattern,
        expression: Expression,
    },
    ConstStatement {
        pattern: Pattern,
        expression: Expression,
    },
    ExpressionStatement {
        expression: Expression,
    },
}

#[derive(Debug)]
pub enum Type {
    Void,
    Int8,
    Int16,
    Int32,
    Int64,
    Int128,
    IntSize,
    UInt8,
    UInt16,
    UInt32,
    UInt64,
    UInt128,
    UIntSize,
    Float32,
    Float64,
    Boolean,
    Char,
    Array {
        type_: Box<Type>,
        length: usize,
    },
    Pointer {
        pointed: Box<Type>,
    },
    Type {
        name: String,
    },
    GenericType {
        name: String,
        types: Vec<Type>,
    },
    Trait {
        trait_: Trait,
    },
}

#[derive(Debug)]
pub enum Trait {
    Trait {
        name: String,
    },
    GenericTrait {
        name: String,
        types: Vec<Type>,
    },
}