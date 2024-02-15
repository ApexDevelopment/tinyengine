# tinyengine
This is a bytecode interpreter written entirely in Windows Batch script. Right now it is incomplete and can only interpret a few Lua-style bytecode instructions.

This project was inspired by [this tweet](https://twitter.com/m_bitsnbites/status/1333005962450505728) by the author of GLFW. I'm not exactly sure what the advantages of this are as opposed to just including Shell/Batch scripts in your project, but it seemed like a fun challenge.

## Limitations
- Some characters cannot be read in from bytecode files because of how Batch interprets them, this includes null bytes and the variable markers (% and !)
- Due to that, lots of space is wasted in the bytecode, namely the two most significant bits of every byte in the file must be `01` (from most to least significant)
- There is no way to natively use floating point numbers, so everything is an integer
- This thing is so ridiculously slow.

## Project Goals
- [ ] Lua-style bytecode implementation
- [ ] Port it to POSIX Shell script (or Bash, whichever seems more reasonable)
- [ ] Write many test scripts to check for parity between Batch and Shell script implementations and to test the VM itself
- [ ] In the long term, optimize for speed and size

## Why This is Probably Useless (and Impractical)
If you really need a cross-platform way to accompany your repository with a script which only uses interpreters built in to the OS, you should probably just use something like [Batsh](https://github.com/batsh-dev-team/Batsh), a language that transpiles to both Batch and Bash. I actually plan to rewrite tinyengine in Batsh to neatly solve the portability issue this project faces, which contains about the same amount of irony as reinventing the wheel using a lathe. Not only will this interpreter likely end up taking more space than just including two Batsh-compiled scripts with your repository, but it will be significantly slower and probably less capable overall. That said, this is all for fun :)

## Etc
Bitsnbites (the author of the tweet that inspired this) has their own [work-in-progress implementation](https://github.com/mbitsnbites/bs) of this idea; however, their version is on ice for now. I guess you could say mine is the most maintained. ;)
