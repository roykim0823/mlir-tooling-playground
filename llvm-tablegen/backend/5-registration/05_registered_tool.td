// Input for the multi-backend tool. Select an output with --gen-names / --gen-count.
class Animal {
  string Sound;
}

def Dog : Animal { let Sound = "woof"; }
def Cat : Animal { let Sound = "meow"; }
def Cow : Animal { let Sound = "moo"; }
