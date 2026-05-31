# tang1k_explore

Just fucking about with a [Tang Nano 1K](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-1K/Nano-1K.html)
dev board (Gowin GW1NZ-1). Random Verilog experiments — nothing serious.

## Layout

```
src/      RTL
constr/   pin (.cst) + timing (.sdc) constraints
gowin/    Gowin IDE project (tang1k.gprj); impl/ build output lands here (gitignored)
scripts/  build.sh — CLI build/flash driver
```

## Build / flash

`scripts/build.sh` reads the device and source list straight out of
`gowin/tang1k.gprj` (single source of truth) and drives the Gowin CLI tools.

```sh
scripts/build.sh            # synth + place & route + bitstream
scripts/build.sh flash      # load to SRAM (volatile)
scripts/build.sh flash-spi  # write to onboard flash (persistent)
scripts/build.sh all        # build, then flash to SRAM
```

Requires GowinIDE (for `gw_sh`) and [openFPGALoader](https://github.com/trabucayre/openFPGALoader)
(`brew install openFPGALoader`). Toolchain paths and board are overridable via the
`GWSH`, `LOADER`, and `LOADER_BOARD` env vars — see the top of the script.

Add new sources through the Gowin IDE so `tang1k.gprj` stays current; the build
script picks them up automatically.
