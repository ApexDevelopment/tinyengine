def make_ascii(c):
	return c | 0b01000000

def to_int24(str):
	n = int(str)
	b1 = n & 0b00111111
	b2 = (n >> 6) & 0b00111111
	b3 = (n >> 12) & 0b00111111
	b4 = (n >> 18) & 0b00111111
	return [make_ascii(b1), make_ascii(b2), make_ascii(b3), make_ascii(b4)]

def main(infile, outfile):
	instructions = {
		# Opcode: [value, number of arguments]
		"MOV": [0x00, 2], # MOV DEST SOURCE
		"LOADK": [0x01, 2], # LOADK DEST CONST_INDEX
		"CALL": [0x02, 3], # CALL FUNC NUM_ARGS NUM_RETURNS
		"UNM": [0x03, 2], # UNM DEST SOURCE
		"NOT": [0x04, 2], # NOT DEST SOURCE
		"LEN": [0x05, 2], # LEN DEST STR
		"ADD": [0x06, 3], # ADD DEST A B
		"SUB": [0x07, 3], # SUB DEST A B
		"MUL": [0x08, 3], # MUL DEST A B
		"DIV": [0x09, 3], # DIV DEST A B
		"MOD": [0x0A, 3], # MOD DEST A B
	}

	# T I N Y
	outfile_bytes = [ 0x54, 0x49, 0x4E, 0x59 ]
	num_constants = 0
	constants_bytes = []
	instructions_bytes = []

	# Read file
	with open(infile) as f:
		lines = f.readlines()
		lines = [line.split("//")[0].strip() for line in lines] # Remove comments
		lines = [line for line in lines if line != ""] # Remove empty lines

	# Parse lines
	for line in lines:
		parts = line.split(" ")
		insn = parts[0].upper()

		if insn not in instructions:
			if insn == "DEF":
				# Define constant
				const_type = parts[1]
				const_value = " ".join(parts[2:])
				if const_type == "int":
					constants_bytes.append(make_ascii(1)) # Type is 1 for int
					constants_bytes += to_int24(const_value)
					num_constants += 1
				elif const_type == "string":
					const_value = const_value[1:-1]
					constants_bytes.append(make_ascii(2)) # Type is 2 for string
					constants_bytes += to_int24(len(const_value))
					constants_bytes += [ord(c) for c in const_value]
					num_constants += 1
				elif const_type == "bool":
					const_value = const_value == "true"
					constants_bytes.append(make_ascii(0)) # Type is 0 for bool
					constants_bytes.append(make_ascii(1 if const_value else 0))
					num_constants += 1
				else:
					raise Exception("Invalid constant type '{}'".format(const_type))
		else:
			# Instruction
			args = parts[1:]
			opcode_value = make_ascii(instructions[insn][0])
			num_args = instructions[insn][1]
			if len(args) != num_args:
				raise Exception("Invalid number of arguments for instruction '{}'".format(insn))
			instructions_bytes.append(opcode_value)
			for arg in args:
				if arg[0] == "$":
					instructions_bytes.append(make_ascii(int(arg[1:])))
				else:
					instructions_bytes.append(make_ascii(int(arg)))
			# Pad out to 3 arguments
			for i in range(num_args, 3):
				instructions_bytes.append(make_ascii(0))

	# Write constants
	outfile_bytes += to_int24(num_constants)
	outfile_bytes += constants_bytes

	# Write instructions
	outfile_bytes += instructions_bytes
	
	# Write file
	with open(outfile, "wb") as f:
		f.write(bytearray(outfile_bytes))
		print("Wrote {} bytes to {}".format(len(outfile_bytes), outfile))

if __name__ == '__main__':
	# Get arguments
	import sys
	if len(sys.argv) != 3:
		print("Usage: assembler.py <infile> <outfile>")
		sys.exit(1)
	main(sys.argv[1], sys.argv[2])