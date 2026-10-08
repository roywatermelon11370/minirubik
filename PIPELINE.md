# Five-stage walkthrough: transition lookup and LED store

This guide describes two sequences actually used by the coordinate solver.
`pipeline_probe.s` links to the same `tables.s`, isolates these instructions,
and adds two observation registers. It is not the solver or a performance test.

Build from this folder using `sh link.sh pipeline_probe.s pipeline-probe.elf`.
Load the ELF in Ripes, choose **32-bit 5-stage processor**, disable M/C, and
select **Extended** layout. Enable **View → Show processor signal values**.
Use Ctrl+mouse-wheel to fit the diagram. F5 advances one clock; the stage table
toolbar shows instruction occupancy and stalls. Register values and the Memory
tab are separate from the pipeline's combinational signals.

These operations are documented in [Ripes Introduction](https://github.com/mortbopet/Ripes/blob/master/docs/introduction.md).
Green 1-bit wires mean one; a mux's green dot marks its selected input. The
following control descriptions and diagram are derived from instruction
semantics. They are not GUI screenshots or observed port traces. Register and
memory results below come from actual Ripes execution.

![Instruction-semantic signal diagram](pipeline-signals.png)

## Halfword transition lookup

The solver uses `slli index,index,1; add address,base,index; lhu next,0(address)`.
The probe starts with permutation rank zero and R's table base `0x10000000`.
The halfword there is 1104 (`0x0450`): R moves the solved permutation to rank
1104. `lhu` zero-extends the halfword, preserving ranks above 32767 if they
were present; this table's actual maximum is 5039.

| Stage | Operation for `lhu a0,0(t2)` | Relevant selection/control |
| --- | --- | --- |
| IF | Fetch the 32-bit instruction; prepare sequential PC+4 | PC mux chooses sequential path |
| ID | Decode load, read t2, form immediate 0 and destination a0 | Load decode; destination x10 |
| EX | ALU adds t2 and immediate 0 | Operand A is forwarded/register t2; B chooses immediate; ALU add |
| MEM | Read two bytes at 0x10000000 and zero-extend | Memory read enabled; unsigned-halfword operation |
| WB | Write 0x00000450 to a0 | Writeback mux chooses memory data; RegWrite=1 |

The probe's following `mv s0,a0` is an `addi` and depends on that load. With
forwarding and hazard detection, ID stalls for the load-use dependency until
the memory result can be forwarded. The preceding address-generating `add`
also feeds the load through forwarding; the forwarding unit selects the
new address instead of a stale register-file value.

## RGB store and readback

The renderer's store form is `sw t5,0(a7)`. The probe writes white at LED
coordinate (9,0): `0xf0000000 + 4*(35*0+9) = 0xf0000024`.

| Stage | Operation for `sw t5,0(a7)` | Relevant selection/control |
| --- | --- | --- |
| IF | Fetch store and PC+4 | Sequential PC selection |
| ID | Read base a7 and color t5; form S-type immediate 0 | Store decode; two source registers |
| EX | Compute a7+0 | ALU A uses base, B chooses immediate, operation add |
| MEM | Write four bytes of 0x00ffffff at 0xf0000024 | MemWrite=1; store data comes from t5/forwarding |
| WB | No register result is written | RegWrite=0; writeback selection is irrelevant |

Little-endian bytes become FF FF FF 00. With the GUI peripheral instantiated,
that word controls one white LED. In CLI, no peripheral exists; the same
address is ordinary simulated memory. The probe reads it back into s1 to
confirm the data write, not to claim that CLI produced a physical LED display.

[Actual Ripes 5-stage result](measurements/completion/pipeline/probe.json)
records RV32I, no extensions, 16 retired instructions, `x8/s0=1104` and
`x9/s1=16777215`. The captured stdout reports guest exit 0. This establishes
the lookup value and memory result; it does not establish observed mux signals.

## Optional direct GUI corroboration

After loading `pipeline-probe.elf`, clock through the load and store. Save a
stage-table screenshot of the load dependency, an Extended-layout screenshot
showing load WB (RegWrite/memory-result selection), and store MEM
(MemWrite/address/data), plus Memory/I/O readback. Identify the cycle and the
instruction at each stage in the captions. Then restore `solver-led.elf` for
the full cube animation. Do not substitute probe instruction counts for the
solver's measurements.
