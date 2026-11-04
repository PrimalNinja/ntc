#!/usr/bin/env python3
# cynthia_corpus.py - a TIGHT chitchat corpus for CYNTHIA (an "ELIZA killer", slow on a Z80). A
# small net can't spell its way through hundreds of templates (it garbles words), so this keeps a
# short set of crisp exchanges and repeats them hard: a line you might type, then Cynthia's reply,
# ended by a form feed (\f) so GRU stops after her line. Greedy output is then clean canned ELIZA.
#   python3 tools/gen/cynthia_corpus.py OUTDIR
# Writes OUTDIR/basic.txt and OUTDIR/asm.txt (a copy; train with --asm-share 0).
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, random
random.seed(7)
out = sys.argv[1]; os.makedirs(out, exist_ok=True)

# a tight set of clean exchanges - short words, simple shapes the net can actually spell
EX = [
    ("hello", "Hello. What is on your mind?"),
    ("hi", "Hi. How are you today?"),
    ("hey", "Hey. Tell me more."),
    ("how are you", "I am a small net, but I am here. And you?"),
    ("what is your name", "I am Cynthia. What is yours?"),
    ("who are you", "Cynthia. Slower than ELIZA, but I listen."),
    ("i feel sad", "Why do you feel sad?"),
    ("i feel happy", "What makes you happy?"),
    ("i am tired", "Why are you tired?"),
    ("i am bored", "What would you like to do?"),
    ("i am lonely", "Tell me more about that."),
    ("i want to go home", "Why do you want to go home?"),
    ("i like music", "What do you like about music?"),
    ("i like you", "Why do you like me?"),
    ("i had a bad day", "What made it a bad day?"),
    ("i had a good day", "What made it good?"),
    ("yes", "Go on."),
    ("no", "Why not?"),
    ("maybe", "What holds you back?"),
    ("i do not know", "Take a guess."),
    ("tell me a joke", "A Z80 walks into a bar and halts."),
    ("you are slow", "Four megahertz does that. Go on."),
    ("thank you", "You are welcome."),
    ("goodbye", "Goodbye. Come back soon."),
    ("bye", "Bye for now."),
]
rows = EX * 300
random.shuffle(rows)
text = ''.join("%s\n%s\f" % (u, c) for u, c in rows)
open(os.path.join(out, 'basic.txt'), 'w').write(text)
open(os.path.join(out, 'asm.txt'), 'w').write(text[:20000])
print('cynthia: %d exchanges, %d rows, %d bytes' % (len(EX), len(rows), len(text)))
