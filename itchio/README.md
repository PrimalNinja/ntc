# NTC - Native Threaded Code

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

What NTC is, how the NTC BASIC compiler works now (VB5/VB6 style front end, turbo and
normal modes, project explorer), and the language it takes. Progress is tracked in
`todo.md`. The full language reference, keyword by keyword, is `userguide.md`; a step by step
tutorial, one small page per topic, is in `tutorial/`. These are in `docs/`; file and folder names in them (`js/`, `asm/`, `bas/` ...) are in `src/`, except `test/`: the test tools are beside `src/` (moved out of it 2026-10-28, so `src/` is what the compiler and the page are made of).

## 1. What NTC is

NTC uses the Z80 stack pointer as the instruction pointer. A program is a thread: a list of
words, each one the address of a keyword (a machine code routine), followed by that
keyword's arguments.

```
main_thread:
        dw kw_ltov, 10, var_x          ; x = 10
        dw kw_printint, var_x          ; Print x
        dw kw_stop
```

## 2. What are these games?

These games form part of the demonstration software on the NTC GitHub Repo. Try make them better.

https://github.com/PrimalNinja/ntc

