# Implementing a Language in C

In this post we're implementing a small programming language in C. The
language, which I extended from
[**tinyc**](http://www.iro.umontreal.ca/~felipe/IFT2030-Automne2002/Complements/tinyc.c)
by **Marc Feeley**, is a statement language. I added a print statement to the
language (which means extending the tokenizer and the parser, and adding a new
machine instruction and modifying the virtual machine interpreter accordingly).
I also removed the restriction that only one-symbol pre-defined identifiers are
allowed; this again leads to changes in the tokenizer, the parser, the
compiler, and the virtual machine interpreter. Moreover, as will be seen, I
added an abstract syntax tree printer and an abstract syntax interpreter to the
program.

In this language a program is simply a statement, where a statement can be a
condition statement, a loop statement, a print statement, an empty statement,
or zero or more statements enclosed in brackets. Each statement is followed by
a semi-colon. To be precise, the definition is shown below in the BNF grammar
of the language. The non-terminals are enclosed in `<>` while the terminals are
shown between double quotes. Note that zero or more is simply enclosed inside a
pair of brackets (instead of the usual `*`).

```
 <program>   := <statement>
 <statement> := "if" <paren_expr> <statement>
             := "if" <paren_expr> <statement> "else" <statement>
             := "while" <paren_expr> <statement>
             := "do" <statement> "while" <paren_expr> ";"
             := "print" <paren_expr> ";"
             := "{" { <statement> } "}"
             := <expr> ";"
             := ";"

 <paren_expr> := "(" <expr> ")"
 <expr>       := <test>
              := <id> "=" <expr>
 <test>       := <sum>
              := <sum> "<" <sum>
 <sum>        := <term>
              := <sum> "+" <term>
              := <sum> "-"  <term>
 <term>       := <id>
              := <int>
              := <paren_expr>
 <id>         := <a_finite_sequence_of_acceptable_symbols>
 <num>        := <an_unsigned_decimal_integer>
```

#### The Tokenizer

As is known, the tokenizer makes available the current token and makes possible
moving to the next token. In general, a token has a type and a value. In our
tokenizer, we have the following token types

```c
enum
{
  DO_SYM,
  ELSE_SYM,
  IF_SYM,
  WHILE_SYM,
  PRINT_SYM,
  LBRA_SYM,
  RBRA_SYM,
  LPAR_SYM,
  RPAR_SYM,
  PLUS_SYM,
  MINUS_SYM,
  LESS_SYM,
  SEMI_SYM,
  EQUAL_SYM,
  NUM_SYM,
  ID_SYM,
  EOI_SYM
};
```

Except `EOI_SYM` to help with parsing later, the other token types are all
obtained from the grammar. Every terminal has a token type, and moreover the
non-terminals that directly generate terminals (`<id>` and `<int>`) also belong
to some token types. The latter two have associated values which we'll keep in
an integer and a string:

```c
int num_val;
char id_name[100];
```

On the other hand, the current token (more precisely the current token type)
and getting the next token type are realized by a variable and a function:

```c
int sym;
void next_sym()
{
  // To be filled in
}
```

In order to signal a syntax error we'll have the function

```c
void syntax_error(char *msg)
{
  fprintf(stderr, "syntax error - %s\n", msg);
  exit(1);
}
```

Now let's write the tokenizer, i.e. implement `next_sym`. The basic idea is
to examine the current character and update the token type kept in `sym`, and
then move on to the next character. In the case of numbers and identifiers the
characters are accumulated and put in `num_val` and `id_name` respectively. So
we'll have first of all

```c
int ch = ' ';
void next_ch() { ch = getchar(); }
```

Space characters are simply ignored, and we'll have

```c
void next_sym()
{
again:
  switch (ch)
  {
  case ' ':
  case '\n':
    next_ch();
    goto again;
  // To be continued
  }
}
```

To continue, when `EOF` is reached, `sym` is updated to `EOI_SYM`.

```c
void next_sym()
{
again:
  switch (ch)
  {
  // ...
  case EOF:
    sym = EOI_SYM;
    break;
  // To be continued
  }
}
```

In the case of `+`, `-`, `=`, and so on, `sym` is updated accordingly, and the
next character is made available by a call to `next_ch()`.

```c
void next_sym()
{
again:
  switch (ch)
  {
  // ...
  case '{':
    next_ch();
    sym = LBRA_SYM;
    break;
  case '}':
    next_ch();
    sym = RBRA_SYM;
    break;
  case '(':
    next_ch();
    sym = LPAR_SYM;
    break;
  case ')':
    next_ch();
    sym = RPAR_SYM;
    break;
  case '+':
    next_ch();
    sym = PLUS_SYM;
    break;
  case '-':
    next_ch();
    sym = MINUS_SYM;
    break;
  case '<':
    next_ch();
    sym = LESS_SYM;
    break;
  case ';':
    next_ch();
    sym = SEMI_SYM;
    break;
  case '=':
    next_ch();
    sym = EQUAL_SYM;
    break;
  // To be continued
  }
}
```

The remaining case is either a number, an identifier, or a syntax error. If the
current character is a digit, we simply accumulate all the following digits,
convert the token to a number and save it in `num_val`, and update `sym` to
`NUM_SYM`:

```c
void next_sym()
{
again:
  switch (ch)
  {
  // ...
  default:
    if (ch >= '0' && ch <= '9')
    {
      num_val = 0;
      while (ch >= '0' && ch <= '9')
      {
        num_val = num_val * 10 + (ch - '0');
        next_ch();
      }
      sym = NUM_SYM;
    }
    // To be continued
  }
}
```

If on the other hand the current character is an alphabet, we're dealing with
an identifier. Here, there is a subtlety: The identifier could be one of the
words in our language, such as `do`, `else`, and so on. Thus we'll have

```c
char *words[] = {"do", "else", "if", "while", "print", NULL};
```

Note the order that we have put the words: the order of `do` match that of
`DO_SYM`, `else` `ELSE_SYM`, and so on. This is so, so that after having
accumulated the characters of an identifier to `id_name` (ended properly with
`\0`), we can reset `sym` to `0` which correponds to the index of `do` in
`words` (and the index of `DO_SYM`). Then we can simply increment `sym` to
check all the words which at the same time makes sure `sym` have the correct
value if a word has indeed been seen. Otherwise we have seen an identifier and
we simply update `sym` to `ID_SYM`. Thus

```c
void next_sym()
{
again:
  switch (ch)
  {
  // ...
  default:
    // ...
    else if (ch >= 'a' && ch <= 'z')
    {
      int i = 0;
      while ((ch >= 'a' && ch <= 'z') || ch == '_' || (ch >= '0' && ch <= '9'))
      {
        id_name[i++] = ch;
        next_ch();
      }
      id_name[i] = '\0';
      sym = 0;
      while (words[sym] != NULL && strcmp(words[sym], id_name) != 0)
        sym++;
      if (words[sym] == NULL)
        sym = ID_SYM;
    }
    // .. To be continued
  }
}
```

Anything else is a syntax error in the language, and we have

```c
void next_sym()
{
again:
  switch (ch)
  {
  // ...
  default:
    // ...
    // ...
    else
      syntax_error("unknown symbol");
  }
}
```

The tokenizer is done. The following function that prints all the tokens should
be written as we were extending the tokenizer:

```c
void print_tokens()
{
again:
  next_sym();
  switch (sym)
  {
  case DO_SYM:
    printf("DO_SYM \"%s\"\n", id_name);
    goto again;
  case ELSE_SYM:
    printf("ELSE_SYM \"%s\"\n", id_name);
    goto again;
  case IF_SYM:
    printf("IF_SYM \"%s\"\n", id_name);
    goto again;
  case WHILE_SYM:
    printf("WHILE_SYM \"%s\"\n", id_name);
    goto again;
  case PRINT_SYM:
    printf("PRINT_SYM \"%s\"\n", id_name);
    goto again;
  case LBRA_SYM:
    printf("LBRA_SYM\n");
    goto again;
  case RBRA_SYM:
    printf("RBRA_SYM\n");
    goto again;
  case LPAR_SYM:
    printf("LPAR_SYM\n");
    goto again;
  case RPAR_SYM:
    printf("RPAR_SYM\n");
    goto again;
  case PLUS_SYM:
    printf("PLUS_SYM\n");
    goto again;
  case MINUS_SYM:
    printf("MINUS_SYM\n");
    goto again;
  case LESS_SYM:
    printf("LESS_SYM\n");
    goto again;
  case SEMI_SYM:
    printf("SEMI_SYM\n");
    goto again;
  case EQUAL_SYM:
    printf("EQUAL_SYM\n");
    goto again;
  case NUM_SYM:
    printf("NUM_SYM \"%d\"\n", num_val);
    goto again;
  case ID_SYM:
    printf("ID_SYM \"%s\"\n", id_name);
    goto again;
  case EOI_SYM:
    printf("EOI_SYM\n");
    break;
  }
}
```

Now a simple demonstration of `{ i=1; while (i<100) i=i+i; }`:

```
LBRA_SYM
ID_SYM "i"
EQUAL_SYM
NUM_SYM "1"
SEMI_SYM
WHILE_SYM "while"
LPAR_SYM
ID_SYM "i"
LESS_SYM
NUM_SYM "100"
RPAR_SYM
ID_SYM "i"
EQUAL_SYM
ID_SYM "i"
PLUS_SYM
ID_SYM "i"
SEMI_SYM
RBRA_SYM
EOI_SYM
```

#### The Parser

In order to write the parser we'll first need to give names to the semantic
constructs in the language, which is done by going through the grammar and
labelling the productions. The following list is complete:

```c
enum
{
  VAR,
  CST,
  ADD,
  SUB,
  LT,
  SET,
  IF,
  IFELSE,
  WHILE,
  DO,
  PRINT,
  EMPTY,
  SEQ,
  EXPR,
  PROG
};
```

Next, we'll need a data structure to hold not only the type of a construct but
also its components. We'll need at maximum three pieces of data (the `IFELSE`
construct) and the following data structure is adequate for all the constructs
in the language:

```c
typedef struct node
{
  int kind;
  struct node *o1, *o2, *o3;

  union {
    int val;
    char id[100];
  };

} node;
```

A new `node` is created by calling the following function:

```c
node *new_node(int k)
{
  node *x = malloc(sizeof(node));
  x->kind = k;
  return x;
}
```

At certain points during the parsing we'll simply need to consume an expected
token type and the following function is useful:

```c
void consume(int expected)
{
  if (sym == expected)
    next_sym();
  else
    syntax_error("unknown expected");
}
```

The parser itself is made up of a set of possibly recursive functions calling each
other according to the grammar. To start, `id` simply creates a new node of
type `VAR` and copies over the content of `id_name`; it also makes the next
token available by calling `next_sym`:

```c
node *id()
{
  node *x = new_node(VAR);
  strcpy(x->id, id_name);
  next_sym();
  return x;
}
```

Next, `num` is likewise:

```c
node *num()
{
  node *x = new_node(CST);
  x->val = num_val;
  next_sym();
  return x;
}
```

Next, according to its grammar, `term` decides which non-terminal to follow
according to the current token type. Note that we need a forward declaration
of `paren_expr()`.

```c
node *paren_expr();

node *term()
{
  if (sym == ID_SYM)
    return id();
  else if (sym == NUM_SYM)
    return num();
  else
    return paren_expr();
}
```

Next in line is `sum`. According to its grammar, there're three productions
none of which begins with a terminal. However, we can expand an addition or a
subtraction and see that a term always needs to be parsed first. Subsequently
it's zero or more additions or subtractions which translates to a loop
structure. Thus

```c
node *sum()
{
  node *x = term();
  while (sym == PLUS_SYM || sym == MINUS_SYM)
  {
    node *t = x;
    x = new_node(sym == PLUS_SYM ? ADD : SUB);
    next_sym();
    x->o1 = t;
    x->o2 = term();
  }
  return x;
}
```

Let's pause a bit here and try to visualize the work of the parser. Given an
expression such as `1 + 2 - 3` we'll get the parsed tree

```
    +
  /   \
 1     -
     /   \
    2     3
```

The next one is `test`:

```c
node *test()
{
  node *x = sum();
  if (sym == LESS_SYM)
  {
    node *t = x;
    x = new_node(LT);
    next_sym();
    x->o1 = t;
    x->o2 = sum();
  }
  return x;
}
```

Now, `expr`, which is a bit tricky. Even though an identifier seems to point to
the second production, if we expand the first production, `<test>`, we see that
it may start with an identifier as well. In the following, we will simply check
if the current token is not an identifier, in which case we parse the first
production by returning what will be parsed by `test`. Otherwise, we call
`test` and check if we have an identifier followed by the equal sign, in which
case we are parsing the `SET` clause, and if not, it's also what has been
parsed by `test`.

```c
node *expr()
{
  if (sym != ID_SYM)
    return test();

  node *x = test();
  if (x->kind == VAR && sym == EQUAL_SYM)
  {
    node *t = x;
    x = new_node(SET);
    next_sym();
    x->o1 = t;
    x->o2 = expr();
  }
  return x;
}
```

Next, `paren_expr`, it's probably the simplest one:

```c
node *paren_expr()
{
  consume(LPAR_SYM);
  node *x = expr();
  consume(RPAR_SYM);

  return x;
}
```

Next is `statement`, which has eight productions and is therefore the longest
function. Seven of them start with a distinct terminal indicating which
production is to be parsed (even though there're two conditional statements,
one can be distinguished from the other by the `else` terminal). Most of them
are straight-forward, except the sequence production. It translates into a loop
structure that keeps parsing and attaching what has been parsed as a component
to what will be parsed. We may roughly see how it works by looking at an
example: The sequence `{ i=1; while (i<100) i=i+i; }` will be parsed by the
parser into the tree below, the lower tree being parsed first and glued to the
upper tree as a branch.

```
         SEQ
       /     \
     SEQ     WHILE
   /    \
EMPTY  EXPR
```

```c
node *statement()
{
  node *x;
  if (sym == IF_SYM)
  {
    next_sym();
    x = new_node(IF);
    x->o1 = paren_expr();
    x->o2 = statement();
    if (sym == ELSE_SYM)
    {
      x->kind = IFELSE;
      next_sym();
      x->o3 = statement();
    }
  }
  else if (sym == WHILE_SYM)
  {
    x = new_node(WHILE);
    next_sym();
    x->o1 = paren_expr();
    x->o2 = statement();
  }
  else if (sym == DO_SYM)
  {
    x = new_node(DO);
    next_sym();
    x->o1 = statement();
    consume(WHILE_SYM);
    x->o2 = paren_expr();
    consume(SEMI_SYM);
  }
  else if (sym == PRINT_SYM)
  {
    x = new_node(PRINT);
    next_sym();
    x->o1 = paren_expr();
    consume(SEMI_SYM);
  }
  else if (sym == LBRA_SYM)
  {
    x = new_node(EMPTY);
    next_sym();
    while (sym != RBRA_SYM)
    {
      node *t = x;
      x = new_node(SEQ);
      x->o1 = t;
      x->o2 = statement();
    }
    next_sym();
  }
  else if (sym == SEMI_SYM)
  {
    x = new_node(EMPTY);
    next_sym();
  }
  else
  {
    x = new_node(EXPR);
    x->o1 = expr();
    consume(SEMI_SYM);
  }

  return x;
}
```

Finally, `program`. We need to remember to consume `EOF_SYM`.

```c
node *program()
{
  node *x = new_node(PROG);
  x->o1 = statement();
  consume(EOI_SYM);
  return x;
}
```

And a function that initiates the parsing:

```c
node *parse()
{
  next_sym();
  node *x = program();
  return x;
}
```

The following function prints the abstract syntrax tree to give us roughly an
idea of how it looks like.

```c
void print_ast(node *x)
{
  switch (x->kind)
  {
  case VAR:
    printf("VAR \"%s\" ", x->id);
    break;
  case CST:
    printf("CST \"%d\" ", x->val);
    break;
  case ADD:
    print_ast(x->o1);
    printf("ADD ");
    print_ast(x->o2);
    break;
  case SUB:
    print_ast(x->o1);
    printf("SUB ");
    print_ast(x->o2);
    break;
  case LT:
    print_ast(x->o1);
    printf("LT ");
    print_ast(x->o2);
    break;
  case SET:
    printf("SET ");
    print_ast(x->o1);
    print_ast(x->o2);
    break;
  case IF:
    printf("IF ");
    print_ast(x->o1);
    print_ast(x->o2);
    break;
  case IFELSE:
    printf("IF ");
    print_ast(x->o1);
    print_ast(x->o2);
    printf("ELSE ");
    print_ast(x->o3);
    break;
  case EXPR:
    printf("EXPR ");
    print_ast(x->o1);
    break;
  case SEQ:
    printf("SEQ ");
    print_ast(x->o1);
    print_ast(x->o2);
    break;
  case PRINT:
    printf("PRINT ");
    print_ast(x->o1);
    break;
  case WHILE:
    printf("WHILE ");
    print_ast(x->o1);
    print_ast(x->o2);
    break;
  case DO:
    printf("DO ");
    print_ast(x->o1);
    printf("WHILE ");
    print_ast(x->o2);
    break;
  case PROG:
    printf("PROG ");
    print_ast(x->o1);
    break;
  case EMPTY:
    printf("EMPTY ");
    break;
  default:
    syntax_error("unknown node");
    break;
  }
}
```

As an example, we may see the output of `{ i=1; while (i<100) i=i+i; }`:

```
PROG SEQ SEQ EMPTY EXPR SET VAR "i" CST "1" WHILE VAR "i" LT CST "100"
EXPR SET VAR "i" VAR "i" ADD VAR "i"
```

Here we see the main node `PROG` that contains a sequence. As we discussed how
a sequence was parsed, i.e. roughly `{ i=1; while (i<100) i=i+i; }` will parsed
into

```
         SEQ
       /     \
     SEQ     WHILE
   /    \
EMPTY  EXPR
```

which was reflected in the output.

#### The Interpreter

This language is a very small subset of the C language and the semantics of its
statements are clear. The only point that should be discussed is scoping.
Usually brackets open a new scope and interpretation should take scoping into
account properly. In the current language, however, we'll simply treat brackets
as a way to group statements, and accordingly there's only one global scope,
instead of different local scopes for different pair of matching brackets. As
an example, in our language the statement `{a = 3; {a = a + a;}; a = a + a; print(a)}` will print `12`, instead of `6`; the inner pair of brackets does
update the variable `a`.

Thus, instead of creating new local environments when entering brackets we will
have a global environment that keeps identifiers and their values. The
environment will be a list

```c
typedef struct list
{
  char *id;
  int value;
  struct list *next;
} list;

list *env;
```

We want to be able to get an identifier, which is an element in the list, and
also be able to look up the value of a given identifier:

```c
list *get_id(char *id)
{
  for (list *lst = env; lst; lst = lst->next)
    if (strcmp(lst->id, id) == 0)
      return lst;

  return (list *)NULL;
}

void lookup_error(char *id)
{
  fprintf(stderr, "error looking up %s\n", id);
  exit(1);
}

int lookup_value(char *id)
{
  list *pid = get_id(id);
  if (pid)
    return pid->value;

  lookup_error(id);
  return -1;
}
```

Finally, we want to be able to add an identifier and its value to the global
environment. Because of our scoping rule, if the identifier already exists its
value will simply be replaced by the new value; otherwise the new name-value
pair will be added to the beginning of the list.

```c
void add_id(char *id, int value)
{
  list *pid = get_id(id);
  if (pid)
  {
    pid->value = value;
    return;
  }

  list *lst = malloc(sizeof(list));
  lst->id = id;
  lst->value = value;
  lst->next = env;
  env = lst;
}
```

Now the interpreter. According to our grammar there should be three functions,
`eval_program`, `eval_statement`, and `eval_expr`. First, `eval-expr`:

```c
int eval_expr(node *x)
{
  node *var;
  int val;

  switch (x->kind)
  {
  case VAR:
    return lookup_value(x->id);
  case CST:
    return x->val;
  case ADD:
    return eval_expr(x->o1) + eval_expr(x->o2);
  case SUB:
    return eval_expr(x->o1) - eval_expr(x->o2);
  case LT:
    return eval_expr(x->o1) < eval_expr(x->o2);
  case SET:
    var = x->o1;
    val = eval_expr(x->o2);
    add_id(var->id, val);
    return val;
  default:
    eval_error();
    return -1;
  }
}
```

Next, `eval_statement`:

```c
void eval_statement(node *x)
{
  switch (x->kind)
  {
  case PRINT:
    printf("%d\n", eval_expr(x->o1));
    break;
  case IF:
    if (eval_expr(x->o1))
      eval_statement(x->o2);
    break;
  case IFELSE:
    if (eval_expr(x->o1))
      eval_statement(x->o2);
    else
      eval_statement(x->o3);
    break;
  case WHILE:
    while (eval_expr(x->o1))
      eval_statement(x->o2);
    break;
  case DO:
    do
      eval_statement(x->o1);
    while (eval_expr(x->o2));
    break;
  case SEQ:
    eval_statement(x->o1);
    eval_statement(x->o2);
    break;
  case EXPR:
    eval_expr(x->o1);
    break;
  case EMPTY:
    break;
  default:
    eval_error();
  }
}
```

Finally, `eval_program`:

```c
void eval_program(node *x)
{
  switch (x->kind)
  {
  case PROG:
    eval_statement(x->o1);
    break;
  default:
    eval_error();
  }
}
```

Let's run the interpreter on the program `{ i=1; j = 10; while (i<100) print(i=i+j); }`

```
11
21
31
41
51
61
71
81
91
101
```

#### The Compiler

A compiler translates a program in our language into a set of bytecote
instructions that will subsequently be interpreted. Each instruction is
associated with a number, and the set of instructions that will be used is

```c
enum
{
  IFETCH,
  ISTORE,
  IPUSH,
  IPOP,
  IADD,
  ISUB,
  ILT,
  IJZ,
  IJNZ,
  IJMP,
  IPRINT,
  IHALT
};
```

The interpretation of the bytecode will be carried out by a stack virtual
machine, starting from the first instruction, with a stack holding computation
values. In addition, there will be two additional arrays to keep variables and
their associated values. Each variable will be put into a specific location on
one array, and the value associated to the variable will be put into the
corresponding location on the other array. The location number will be used as
a bytecode instruction.

Please note that we are operating at a very low level.

To start, the instructions are put into an array called `object`. Since we'll
keep pushing the instructions on top of the array, we need a pointer, `here`.
The function `g` simply puts a given bytecode on top of the code array and
moves up one element.

```c
typedef char code;
code object[1000], *here = object;

void g(code c) { *here++ = c; }
```

As we have said, there are two arrays holding the variables and their
associated values. We're restricting to only maximum a hundred names, and
therefore a hundred values.

```c
char names[100][100], (*namespt)[100] = names;

int globals[100];
```

An important operation on `names` is getting the index of a variable. If the
variable is already in the array, its index will be returned; otherwise the
variable is put on top of the array and the index of the top element is
returned:

```c
int get_index(char *name)
{
  int i;
  for (char(*npt)[100] = names; npt < namespt; npt++)
  {
    i = npt - names;
    if (strcmp(name, names[i]) == 0)
      return i;
  }
  i = namespt++ - names;
  strcpy(names[i], name);
  return i;
}
```

Let's move on to generating the code. We'll write a function called `c` that
takes an abstract syntax tree and generates the corresponding code.

```c
void c(node *x)
{

  switch (x->kind)
  {
    // To be continued
  }
}
```

Since `PROG` is the containing node, let's work on that first. We need to
generate the bytecode and put `IHALT` at the end. Thus,

```c
void c(node *x)
{

  switch (x->kind)
  {
    case PROG:
      c(x->o1);
      g(IHALT);
      break;
    // To be continued
  }
}
```

Now, according to the grammar of the language, there're eight different kinds
of nodes that could be contained in a `PROG` node. The easiest one is `EMPTY`:

```c
void c(node *x)
{

  switch (x->kind)
  {
    // To be continued
    case EMPTY:
      break;
    // ...
  }
}
```

Let's pick `EXPR` as the next one. In this case a value is expected to be
computed and put on the virtual machine stack, before being used. Thus we'll
generate the instructions followed by the `IPOP` instruction.

```c
void c(node *x)
{

  switch (x->kind)
  {
    // To be continued
    case EXPR:
      c(x->o1);
      g(IPOP);
      break;
    // ...
  }
}
```

There're several possible expressions. Let's start with `VAR`. Given a
variable, as there is already a value associated with it, we simply generate
`IFETCH` and the index of the location of the variable:

```c
void c(node *x)
{

  switch (x->kind)
  {
    case VAR:
      g(IFETCH);
      g(get_index(x->id));
      break;
    // ...
  }
}
```

Next, `CST`. In this case we generate `IPUSH` and the value to be put to the
virtual machine stack:

```c
void c(node *x)
{

  switch (x->kind)
  {
    // ...
    case CST:
      g(IPUSH);
      g(x->val);
      break;
    // To be continued
    // ...
  }
}
```

Next are `ADD` and `SUB`:

```c
void c(node *x)
{

  switch (x->kind)
  {
    // ...
    case ADD:
      c(x->o1);
      c(x->o2);
      g(IADD);
      break;
    case SUB:
      c(x->o1);
      c(x->o2);
      g(ISUB);
      break;
    // To be continued
    // ...
  }
}
```

`LT` is similar:

```c
void c(node *x)
{

  switch (x->kind)
  {
    // ...
    case LT:
      c(x->o1);
      c(x->o2);
      g(ILT);
      break;
    // To be continued
    // ...
  }
}
```

Finally, `SET`. Here we compute the value to be set first, then store it, then
generate the index of the variable:

```c
void c(node *x)
{

  switch (x->kind)
  {
    // ...
    case SET:
      c(x->o2);
      g(ISTORE);
      g(get_index(x->o1->id));
      break;
    // To be continued
    // ...
  }
}
```

Now let's get back to the nodes that could be contained in the `PROG` node. We
have implemented `EMPTY` and `EXPR`. The next easy one is `PRINT`:

```c
void c(node *x)
{

  switch (x->kind)
  {
    // ...
    case PRINT:
      c(x->o1);
      g(IPRINT);
      break;
    // To be continued
    // ...
  }
}
```

`SEQ` is also straight-forward:

```c
void c(node *x)
{

  switch (x->kind)
  {
    // ...
    case SEQ:
      c(x->o1);
      c(x->o2);
      break;
    // To be continued
    // ...
  }
}
```

Next, let's move on to `IF`. The key to translating this node is to use the
instruction `IJZ`, meaning jump if zero. Before writing the code, we will look
at an example, `if (1 < 10) print(10);`. Here the condition `1 < 10` will be
translated into a series of instructions, which we'll mark `X` below:

```
... |X| | |...
```

`print(10)` must be translated too, but whether or not it should be executed
depends on whether the condition is true (`1`), in other words the sequence of instructions should be skipped if the condition is false (`0`). To achieve
this effect, we put `IJZ` followed by a hole, and generate the instructions
for `print(10)`. The hole is to hold the number of instructions to be skipped.
We can keep the following illustration in mind:

```
... |X|IJZ| |X|...
```

To create a hole, we have the function

```c
code *hole() { return here++; }
```

And to compute the number of steps:

```c
void fix(code *src, code *dst) { *src = dst - src; }
```

The code for translating `IF` is:

```c
void c(node *x)
{

  switch (x->kind)
  {
    // ...
    case IF:
      c(x->o1);
      g(IJZ);
      p1 = hole();
      c(x->o2);
      fix(p1, here);
      break;
    // To be continued
    // ...
  }
}
```

Next we will translate `IFELSE`. We'll use a concrete example, `if (1<10) print(1); else print(10);`, to follow along. The code for `1<10`, `print(1)`,
and `print(10)` will need to be translated. In a general statement, one of the
consequences will be skipped depending on the condition. Thus we will place
a jump instruction and a hole in front of each. But the second jump is a simple
jump. Thus we use the `IJMP` instruction.

```
...|X|IJZ| |X|JMP| |X| |...
```

The addresses to be kept in the hole need to be calculated at the right places:

```c
void c(node *x)
{

  switch (x->kind)
  {
    // ...
    case IFELSE:
      c(x->o1);
      g(IJZ);
      p1 = hole();
      c(x->o2);
      g(IJMP);
      p2 = hole();
      fix(p1, here);
      c(x->o3);
      fix(p2, here);
      break;
    // To be continued
    // ...
  }
}
```

Now translating `WHILE`. This works almost like a condition. We'll have

```
|X|IJZ| |X|IJMP|...
```

We need to be careful with the calculation of the jumping addresses:

```c
void c(node *x)
{

  switch (x->kind)
  {
    // ...
    case WHILE:
      p1 = here;
      c(x->o1);
      g(IJZ);
      p2 = hole();
      c(x->o2);
      g(IJMP);
      fix(hole(), p1);
      fix(p2, here);
      break;
    // To be continued
    // ...
  }
}
```

Finally, `DOWHILE`. Here the `JNZ`, or jump if not zero, is used.

```c
void c(node *x)
{

  switch (x->kind)
  {
    // ...
    case DO:
      p1 = here;
      c(x->o1);
      c(x->o2);
      g(JNZ);
      fix(hole(), p1);
      break;
    // ...
  }
}
```

#### The Virtual Machine Interpreter

The bytecode instructions generated by the compiler written above are
interpreted by a stack virtual machine interpreter. There is a stack to hold
computation values, and the instructions are to be interpreted from beginning
to end.

```c
void run()
{
  int stack[1000], *sp = stack;
  code *pc = object;
again:
  switch (*pc++)
  {
    // To be continued ...
  }
}
```

The following instructions manipulate the stack or the value array directly:

```c
void run()
{
  int stack[1000], *sp = stack;
  code *pc = object;
again:
  switch (*pc++)
  {
  case IFETCH:
    *sp++ = globals[*pc++];
    goto again;
  case ISTORE:
    globals[*pc++] = sp[-1];
    goto again;
  case IPUSH:
    *sp++ = *pc++;
    goto again;
  case IPOP:
    --sp;
    goto again;
  case IADD:
    sp[-2] = sp[-2] + sp[-1];
    --sp;
    goto again;
  case ISUB:
    sp[-2] = sp[-2] - sp[-1];
    --sp;
    goto again;
  case ILT:
    sp[-2] = sp[-2] < sp[-1];
    --sp;
    goto again;
  case IPRINT:
    printf("%d\n", *--sp);
    goto again;
    // To be continued ...
  }
}
```

The remaining instructions involve using the number of steps to jump when
needed:

```c
void run()
{
  int stack[1000], *sp = stack;
  code *pc = object;
again:
  switch (*pc++)
  {
    // ...
  case IJZ:
    if (*--sp == 0)
      pc += *pc;
    else
      pc++;
    goto again;
  case IJMP:
    pc += *pc;
    goto again;
  case IJNZ:
    if (*--sp != 0)
      pc += *pc;
    else
      pc++;
    goto again;
  }
}
```

The virtual machine has been completed. Given a program, such as `{ i = 0; do { i = i + 10; print(i);} while (i < 50);}`, it will produces the output

```
10
20
30
40
50
```
