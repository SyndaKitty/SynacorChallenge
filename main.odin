package main

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:os"

debug := false;

opcodes_const :: [?]string {
    "halt",
    "set",
    "push",
    "pop",
    "eq",
    "gt",
    "jmp",
    "jt",
    "jf",
    "add",
    "mult",
    "mod",
    "and",
    "or",
    "not",
    "rmem",
    "wmem",
    "call",
    "ret",
    "out",
    "in",
    "noop"
};

main :: proc() {
    opcodes := opcodes_const;

    bin := #load("challenge.bin");
    program := mem.slice_data_cast([]u16, bin);
    
    // TODO: clean this up, load directly into memory from file
    memory := make([]u16, 32767);
    for datum,i in program {
        memory[i] = datum;
    }

    registers := make([]u16, 8);
    pc: u16 = 0;
    ic := 0;

    stack := make([]u16, max(u16));
    sp: u16 = 0;

    output_buffer := strings.make_builder();

    input_offset: i64 = 0;

    for {
        opcode := memory[pc];
        pc += 1;

        if debug do fmt.print(opcodes[opcode], "");
        switch opcode {
            
            case 0:
                if debug do fmt.println();
                fmt.println(strings.to_string(output_buffer));
                return;

            case 1: // set register
                a := arg(&memory, &pc, &registers, true);
                b := arg(&memory, &pc, &registers, false);
                assert(a < 8);
                registers[a] = b;

            case 2: // push
                a := arg(&memory, &pc, &registers, false);
                stack[sp] = a;
                sp += 1;

            case 3: // pop
                assert(sp >= 0);
                val := stack[sp-1];
                sp -= 1;
                
                a := arg(&memory, &pc, &registers, true);
                registers[a] = val;

            case 4: // equal
                a := arg(&memory, &pc, &registers, true);
                b := arg(&memory, &pc, &registers, false);
                c := arg(&memory, &pc, &registers, false);

                if b == c {
                    registers[a] = 1;
                }
                else {
                    registers[a] = 0;
                }

            case 5: // greater than
                a := arg(&memory, &pc, &registers, true);
                b := arg(&memory, &pc, &registers, false);
                c := arg(&memory, &pc, &registers, false);

                if b > c {
                    registers[a] = 1;
                }
                else {
                    registers[a] = 0;
                }
            case 6: // jump
                a := arg(&memory, &pc, &registers, false);
                pc = a;

            case 7: // jt: jump non-zero
                a := arg(&memory, &pc, &registers, false);
                b := arg(&memory, &pc, &registers, false);

                if a != 0 {
                    pc = b;
                }

            case 8: // jf: jump equal-zero
                a := arg(&memory, &pc, &registers, false);
                b := arg(&memory, &pc, &registers, false);

                if a == 0 {
                    pc = b;
                }

            case 9: // add
                a := arg(&memory, &pc, &registers, true);
                b := arg(&memory, &pc, &registers, false);
                c := arg(&memory, &pc, &registers, false);
                sum := (b + c) % 32768;
                registers[a] = sum;

            case 10: // mult
                a := arg(&memory, &pc, &registers, true);
                b := arg(&memory, &pc, &registers, false);
                c := arg(&memory, &pc, &registers, false);
                product := (b * c) % 32768;
                registers[a] = product;

            case 11: // mod
                a := arg(&memory, &pc, &registers, true);
                b := arg(&memory, &pc, &registers, false);
                c := arg(&memory, &pc, &registers, false);
                mod := b % c;
                registers[a] = mod;

            case 12: // and
                a := arg(&memory, &pc, &registers, true);
                b := arg(&memory, &pc, &registers, false);
                c := arg(&memory, &pc, &registers, false);
                val := b & c;
                registers[a] = val;

            case 13: // or
                a := arg(&memory, &pc, &registers, true);
                b := arg(&memory, &pc, &registers, false);
                c := arg(&memory, &pc, &registers, false);
                val := b | c;
                registers[a] = val;

            case 14: // not
                a := arg(&memory, &pc, &registers, true);
                b := arg(&memory, &pc, &registers, false);
                val := b ~ 32767;
                registers[a] = val;

            case 15: // rmem
                a := arg(&memory, &pc, &registers, true);
                b := arg(&memory, &pc, &registers, false);
                if debug do fmt.print("->", memory[b]);
                registers[a] = memory[b];

            case 16: // wmem
                a := arg(&memory, &pc, &registers, false);
                b := arg(&memory, &pc, &registers, false);
                memory[a] = b;

            case 17: // call
                a := arg(&memory, &pc, &registers, false);
                stack[sp] = pc;
                sp += 1;
                pc = a;

            case 18: // ret
                val := stack[sp - 1];
                sp -= 1;
                pc = val;

            case 19: // write
                a := arg(&memory, &pc, &registers, false);
                strings.write_rune_builder(&output_buffer, cast(rune) a);

            case 20: // in
                fmt.println(strings.to_string(output_buffer));
                strings.destroy_builder(&output_buffer);
                output_buffer = strings.make_builder();
                input_data := make([]byte, 1);
                a := arg(&memory, &pc, &registers, true);
                
                for {
                    os.read_at(os.stdin, input_data, input_offset);
                    input_offset += 1;
                    ascii := cast(u16)input_data[0];
                    if ascii == 13 { // Ignore carriage return
                        continue;
                    }
                    registers[a] = ascii;
                    break;
                }

                delete(input_data);

            case 21: // noop
                break;

            case:
                fmt.println("Unknown code:", opcode);
                return;
        }
        ic += 1;
        // if ic == 800_000 {
        //     debug = true;
        // }

        if debug
        {
            fmt.println();
            // fmt.println("buffer:", strings.to_string(buffer));
        }
    }
}

// West south north
// _ + _ * _^2 + _^3 - _ = 399
// blue coin = 9
// red = 2
// shiny coin = 5
// concave coin = 7
// corroded coin = 3
// 9 2 5 7 3

arg :: inline proc(memory: ^[]u16, pc: ^u16, registers: ^[]u16, set: bool) -> u16 {
    val := memory[pc^];
    pc^ += 1;

    if debug {
        fmt.print(val, "");
    }

    if 32768 <= val && val <= 32775 {
        if set do return val - 32768;
        val = registers[val - 32768];
        if debug {
            fmt.print("->", val, "");
        }
    }
    
    return val;
}