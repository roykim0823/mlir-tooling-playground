// Input for the skeleton backend — a couple of trivial records.
class Greeting {
  string Message;
}

def Hello : Greeting { let Message = "hello"; }
def Bye   : Greeting { let Message = "bye"; }
def Nop;
