# tinyengine
This is a bytecode interpreter written entirely in Windows Batch script. Right now it is incomplete and can only interpret a few Lua-style bytecode instructions.

This project was inspired by [this tweet](https://twitter.com/m_bitsnbites/status/1333005962450505728) by the author of GLFW. I'm not exactly sure what the advantages of this are as opposed to just including Shell/Batch scripts in your project, but it seemed like a fun challenge.

## Limitations:
- Some characters cannot be read in from bytecode files because of how Batch interprets them, this includes null bytes and the variable markers (% and !)
- Due to that, lots of space is wasted in the bytecode, namely the two most significant bits of every byte in the file must be `01` (from most to least significant)
- There is no way to natively use floating point numbers, so everything is an integer

## Project Goals:
- [ ] Lua-style bytecode implementation
- [ ] Port it to POSIX Shell script (or Bash, whichever seems more reasonable)
- [ ] Write many test scripts to check for parity between Batch and Shell script implementations and to test the VM itself
- [ ] In the long term, optimize for speed and size