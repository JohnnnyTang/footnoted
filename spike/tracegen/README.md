# tracegen

M0 spike (S01-10): seeded five-year synthetic trace generator. Throwaway; removed at G1.

Brief: `stages/01-foundation/W1-spike.md` → S01-10. Shared formats: [`../FORMAT.md`](../FORMAT.md).

```
cd spike/tracegen
dart run tracegen --seed 42 --years 5 --out ../out            # z20: dataset.*
dart run tracegen --seed 42 --years 5 --levels 20,21 --out ../out   # also dataset.z21.*
```

Writes `dataset.trace.ndjson`, `dataset.cells.bin` + `.json`, `dataset.segcells.bin` + `.json` and a
`dataset.stats.json` with the counts and timings (not part of FORMAT.md). Other levels use the
`dataset.z<L>.*` names. About 10 s for z20 and 40 s for z21 on the dev machine; the z21 segcells file is ~290 MB.

Scenario (seed-independent shape, seeded detail): home Mexico City (daily commutes, weekend walks and
drives), three road trips on the CDMX → Monterrey → Nuevo Laredo corridor (one single 1,033 km leg),
twelve flights including HND → HNL across the antimeridian, stays in Madrid, Tokyo and Helsinki (plus
Cancún, Honolulu, Monterrey). The size knob is `--walk-scale`; the session note records why the
road corridor, not the walks, dominates the cell count.
