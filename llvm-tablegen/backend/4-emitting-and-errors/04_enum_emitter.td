// Input for the enum-emitting backend. Each EnumCase carries an int value.
//
// Try breaking it to see the error helpers in action: give two cases the same
// value, or a negative one, and re-run — TableGen will point at the bad `def`.
class EnumCase<int v> {
  int Value = v;
}

def Red   : EnumCase<0>;
def Green : EnumCase<1>;
def Blue  : EnumCase<2>;
