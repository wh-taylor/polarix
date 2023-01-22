# polarix

Polarix is a programming language with the intent to balance
speed, safety, and simplicity.
Inspiration is taken from a variety of languages
like Lua, Rust, C, Haskell, and Zig.

Be aware that Polarix is still in its early stages.

It isn't that good.

Yet.

## Getting Started

When a program is run, the interpreter begins with the `main` function.

```
fn main() {
    println("Hello, world!");
}
```

The code above will simply print "Hello, world!" to the console. Classic.

To run the code, first make sure that the code is in a file. The standard file
extension for Polarix is `.px`, though any file name would work.

Simply open up a console and run the command `lua polarix.lua <filename>`. Of
course, replace the `<filename>` part with the actual name of your file.

If you were to name the file `main.px`, run `lua polarix.lua main.px`.

## Functions

Functions can be written in one of two ways:

```
fn average(x: Num, y: Num): Num {
    let sum = x + y;
    sum / 2
}
```

<sup>The `average` function here returns the mean value of its two inputs.</sup>

This type of function syntax is the more common variant found across
many popular languages. It simply takes a series of statements, but similar to
Rust, the last line can be an expression without a semicolon to indicate that
the expression is returned.

```
fn average(x: Num, y: Num): Num = (x + y) / 2;
```

This syntax is more appropriate when a function can *easily* be encapsulated
into returning a single expression, or if you really like Haskell.

Functions can be called, like many popular languages, with their name followed
by parentheses listing their parameters.

For example, you could have a program like such:

```
fn average(x: Num, y: Num): Num = (x + y) / 2;

fn main() {
    println(average(2, 3));
}
```

Running this would print `2.5` to the console.

### Chaining Function Calls

Another cool thing you can do with functions is that you can use a dot
operator to pass a value as the first argument to a function.

Rather than nesting parentheses within each other like above, you can
simply write:

```
fn main() {
    average(2, 3).println();
}
```

The return value of `average(2, 3)` is immediately passed over to the
`println` function. This is a better alternative if you want to minimize
nesting parentheses OR you just think about printing after you already
wrote the value out.

You could even just chain a bunch of functions together:

```
fn main() {
    1.add_one().average(3).println();
}
```

Obviously, this is a silly example, but can be useful in many situations
where you'd typically need to either nest function calls within each other
or declare a bunch of variables to try to make things look neater. This
looks much better than...

```
fn main() {
    println(average(add_one(1), 3));
}
```

...or even...

```
fn main() {
    let added_one = add_one(1);
    let averaged = average(added_one, 3);
    println(averaged);
}
```

### Functions are Values

Digging further, functions are really just values that are called using
the call operator. This means that we can do things like set variables to
functions and call those variables or take functions as parameters themselves.

Here is an example of a function being set to a variable:

```
fn average(x: Num, y: Num): Num = (x + y) / 2;

fn main() {
    let do_thing = average;
    do_thing(2, 3).println();
}
```
<sub>Outputs `2.5`</sub>

And here is an example of a function being passed as a parameter:

```
fn average(x: Num, y: Num) = (x + y) / 2;

fn do_another_thing(f: NotSureWhatTheFunctionTypeLooksLikeYet, x: Num, y: Num): Num {
    f(x, y)
}

fn main() {
    do_another_thing(average, 2, 3).println();
}
```
<sub>No way! This also outputs `2.5`.</sub>
