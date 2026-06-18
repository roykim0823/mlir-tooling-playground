// Input for the record-walking backend.
class Instruction {
  int    Opcode;
  string Mnemonic;
  bit    IsTerminator = 0;
}

def ADD : Instruction { let Opcode = 1;   let Mnemonic = "add"; }
def SUB : Instruction { let Opcode = 2;   let Mnemonic = "sub"; }
def JMP : Instruction { let Opcode = 100; let Mnemonic = "jmp"; let IsTerminator = 1; }
def RET : Instruction { let Opcode = 101; let Mnemonic = "ret"; let IsTerminator = 1; }
