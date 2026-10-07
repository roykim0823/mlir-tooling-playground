// RUN: %writing_bin/05-registered-tool --gen-names %s | FileCheck --check-prefix=NAMES %s
// RUN: %writing_bin/05-registered-tool --gen-count %s | FileCheck --check-prefix=COUNT %s
// RUN: %writing_bin/05-registered-tool --help | FileCheck --check-prefix=HELP %s
// REQUIRES: writing-build
//
// Input for the multi-backend tool. Select an output with --gen-names / --gen-count.
class Animal {
  string Sound;
}

def Dog : Animal { let Sound = "woof"; }
def Cat : Animal { let Sound = "meow"; }
def Cow : Animal { let Sound = "moo"; }

// NAMES:      // Cat says "meow"
// NAMES-NEXT: // Cow says "moo"
// NAMES-NEXT: // Dog says "woof"
// COUNT:      // 3 animal(s)
// Each OptClass is an option, listed under "Action to perform" in the order
// the registrations ran.
// HELP:       Action to perform:
// HELP-NEXT:    --gen-names - Emit each animal's name and sound
// HELP-NEXT:    --gen-count - Emit the number of animals
