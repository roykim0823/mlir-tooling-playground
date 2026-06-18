// Input for the Init-hierarchy backend: one record with a value of every kind.
class Color;
def Red : Color;

def reg;   // a stub operator for the dag below

def Showcase {
  bit        Flag    = 1;
  int        N       = 42;
  bits<8>    Opcode  = 0b10110010;
  string     S       = "hi";
  list<int>  Xs      = [1, 2, 3];
  Color      Ref     = Red;
  dag        Pattern = (reg 1, 2);
  string     Missing = ?;          // unset
}
