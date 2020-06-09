# ast4gen
Generic AST in Coffeescript

This is [Abstract Syntax Tree](https://en.wikipedia.org/wiki/Abstract_syntax_tree) primarily used  in Solidity to LIGO transpiler. It goes bundled with [types](https://github.com/madfish-solutions/ast4gen-type) helper

It implements the following nodes:
    * Const
    * Array_init
    * Hash_init. Initialization list for maps
    * Struct_init
    * Var
    * Bin_op
    * Un_op
    * Field_access. Like `foo.bar`
    * Fn_call
    * Scope. List of operations inside `for` loop for example
    * If
    * Switch
    * Loop
    * Break
    * Continue
    * While
    * For_range. Like `for i in [1 .. 10]`, `for i in [1 .. 10] by 1`
    * For_array. Like `for v in array`, `for v,k in array`
    * For_hash. Like `for k of hash`, `for k,v of hash`
    * Ret. Return values
    * Try
    * Throw
    * Var_decl
    * Class_decl
    * Fn_decl
