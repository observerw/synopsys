# PDK paths

Each directory under `/data2/synopsys/pdk/` is a PDK root. Mount the chosen
root read-only at `/pdks`; the variant names (`sky130A`, `gf180mcuD`, ...) are
relative symlinks into `ciel/<family>/versions/<commit>/`.

| Directory under `/data2/synopsys/pdk/` | Contents | Used by |
| --- | --- | --- |
| `sky130` | `sky130A`, `sky130B` | flows that need the pristine tree |
| `sky130-dc` | same, plus `db/*.db` | Design Compiler, PrimeTime, Formality |
| `gf180mcu`, `gf180mcu-dc` | `gf180mcuA`-`gf180mcuD` | same split |
| `ihp-sg13`, `ihp-sg13-dc` | `ihp-sg13g2`, `ihp-sg13cmos5l` | same split |
| `freepdk45`, `freepdk45-dc` | `freepdk45` | same split |
| `asap7` | `asap7sc7p5t_28`, `asap7sc7p5t_27`, `asap7sc6t_26`, `asap7_pdk_r1p7`, `asap7_sram_0p0`, `asap7_snps` | OpenROAD, StarRC, IC Compiler |
| `asap7-dc` | same, plus extracted TT Liberty and `db/*.db` | Design Compiler, PrimeTime, Formality |
| `smic-l28hpc-r1p0` | `sc12mcpp140z_*`, `memory/`, `IPs/`, `VERSION` | Design Compiler, PrimeTime (SMIC 28HPC+) |

For the variant-layout PDKs, mount the root at `/pdks` and set
`PDK_ROOT=/pdks`; library paths then start with `/pdks/<variant>/...`.

## sky130

- Tree: `/pdks/<pdk>/libs.ref/<scl>/` with `db/`, `lib/`, `verilog/`, `lef/`,
  `gds/`, `spice/`.
- Design Compiler:
  `set target_library /pdks/sky130A/libs.ref/sky130_fd_sc_hd/db/sky130_fd_sc_hd__tt_025C_1v80.db`
- PrimeTime and Formality read the same `.db` from `sky130-dc`.

## SMIC 28HPC+

- Root files: `/pdks/VERSION`,
  `/pdks/sc12mcpp140z_<flavour>_<vt>_c<30|35>/r1p0/`, `/pdks/memory`,
  `/pdks/IPs`.
- Flavours `base`, `hpk`, `pmk`; VTs `rvt`, `lvt`, `ulvt`, `hvt`; library
  variants `c30`, `c35`.
- Views under `r1p0/`: `db-ccs-tn/` (CCS timing DB for DC and PT), `lib/`,
  `lef/`, `verilog/`, `milkyway/`, `oa/`, `cdl/`, `aocv/`, `sdb/`.
- Memory compiler output in `memory/<macro>/` (`.db`, `.lib`, `.lef`, `.gds2`);
  IP views follow each vendor's layout under `IPs/<ip>/`.

```tcl
set target_library [glob /pdks/sc12mcpp140z_base_rvt_c30/r1p0/db-ccs-tn/*tt_ctypical_max_0p90v_25c.db_ccs_tn]
set link_library   "* $target_library"
```

## ASAP7

- No `PDK_ROOT` and no variant symlinks: mount `asap7` or `asap7-dc` at `/pdks`
  and pass file paths to the flow.
- `/pdks/asap7sc7p5t_28/` current 7.5-track cells;
  `/pdks/asap7sc7p5t_27/` and `/pdks/asap7sc6t_26/` older 7.5-track and 6-track
  sets; `/pdks/asap7_pdk_r1p7/` PDK models, rule dirs and `cdslib/`;
  `/pdks/asap7_snps/` Synopsys supplement.
- Technology LEF:
  `/pdks/asap7sc7p5t_28/techlef_misc/asap7_tech_1x_201209.lef` (`_4x_` for the
  4x grid).
- Cell LEF:
  `/pdks/asap7sc7p5t_28/LEF/asap7sc7p5t_28_<L|R|SL|SRAM>_1x_220121a.lef`;
  4x variants in `LEF/scaled/`. GDS, Verilog and CDL in `GDS/`, `Verilog/`,
  `CDL/LVS/`.
- Filler, tap and decap cells come from the `SIMPLE` family:
  `FILLER_ASAP7_75t_R`, `TAPCELL_ASAP7_75t_R`, `DECAPx10_ASAP7_75t_R`.
- Timing: the pristine `asap7` tree keeps `LIB/NLDM/` and `LIB/CCS/` as
  `*.lib.7z`, one per family (`AO`, `INVBUF`, `OA`, `SEQ`, `SIMPLE`) x VT
  (`LVT`, `RVT`, `SLVT`, `SRAM`) x corner (`TT`, `FF`, `SS`). `asap7-dc` has
  the TT NLDM archives unpacked in `LIB/NLDM/`.
- Design Compiler, PrimeTime and Formality: mount `asap7-dc` and read the
  compiled views; `RVT` only, or all VTs to let the tool mix them. The Liberty
  uses 1 ps and 1 fF units, so periods and delays are in ps:

  ```tcl
  set target_library [glob /pdks/asap7sc7p5t_28/LIB/db/*_RVT_TT_*.db]
  set link_library   "* $target_library"
  create_clock -name clk -period 1000 [get_ports clk]
  ```

  SRAM macro views are in `/pdks/asap7_sram_0p0/generated/db/*.db`. Working
  example: [dc-asap7-job.yaml](../examples/dc-asap7-job.yaml).
- For another corner, extract the archive from the pristine tree on a workspace
  that has `7z` (the tool images do not) and convert it with Library Compiler,
  using the library name from its `library (...)` line:

  ```sh
  7z x /data2/synopsys/pdk/asap7/asap7sc7p5t_28/LIB/NLDM/asap7sc7p5t_AO_RVT_TT_nldm_211120.lib.7z
  lc_shell -x "read_lib asap7sc7p5t_AO_RVT_TT_nldm_211120.lib; \
    write_lib asap7sc7p5t_AO_RVT_TT_nldm_211120 -format db \
    -output db/asap7sc7p5t_AO_RVT_TT_nldm_211120.db; exit"
  ```

  The four `INVBUF_*_TT_nldm_220122` archives keep the older `..._211120` name
  inside, so take the name from the file rather than from the archive name.
  `lc_shell` X-2025.06 writes the `.db` and then reports
  `Fatal: Internal system error` on exit with status 0, so check the output
  file.
- StarRC: `/pdks/asap7_snps/starrc/asap07.itf.x4` with `asap07.layermap`; the
  `Makefile` there builds `tlu_plus` and `.nxtgds` from the ITF.
- IC Compiler: `/pdks/asap7_snps/icc/asap07_icc.tf`.
- SRAM banks: LEF and Liberty in `asap7_sram_0p0/generated/{LEF,LIB}/`
  (compiled views in `generated/db/` on `asap7-dc`), Verilog in
  `asap7_sram_0p0/verilog/`, GDS in `asap7_sram_0p0/gds/`.

## Inside the desktop image

`local.io/synopsys/synopsys:2025.06` bakes two PDK trees and needs no `/pdks`
mount for the open PDKs:

| Path | Contents |
| --- | --- |
| `/opt/pdk` | PDK root with the typical-corner DC `.db` views; `PDK_ROOT` default |
| `/opt/pdk/pristine` | pristine tree without `.db` views |

ASAP7 is not packaged into the desktop image; mount `pdk/asap7-dc` at `/pdks`
when a flow needs it.
