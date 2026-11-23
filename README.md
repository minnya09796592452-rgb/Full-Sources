

## 30. Output 11 — four-grid query-array copying and serialized shader pass metadata

Source: [Output 11](https://github.com/minnya09796592452-rgb/Full-Sources/blob/6c8b507266fda7c550349c122def080a0a009a7c/Outputs/Output%2011)

### 30.1 QueryDisplacements.CopyAndCreateDisplacements

The supplied method checks that the source list contains exactly `GRIDS` entries and that `source[0].Channels` equals `CHANNELS`. It then creates a four-entry destination array, with each destination constructed from the corresponding source `Data`:

- `des[0]` from `source[0].Data`
- `des[1]` from `source[1].Data`
- `des[2]` from `source[2].Data`
- `des[3]` from `source[3].Data`

Each destination uses `sX × sX`, `CHANNELS`, and `wrap: true`. The dimension `sX` is taken from `source[0].SX`.

### 30.2 QueryDisplacements.CopyDisplacements

The copy method repeats the same source-count and first-buffer channel-count checks, then copies all four data arrays individually:

`des[0].Copy(source[0].Data)` through `des[3].Copy(source[3].Data)`.

This confirms that the CPU query-array copy helpers explicitly handle all four grid slots. It does not prove that the GPU readback path fills all four slots: Output 8's displayed `ReadFromGPU` body still showed readback only for grids 0–2. Also, the methods shown validate the channel count of source[0], not separately each source entry; no additional validation should be inferred.

### 30.3 ComputeShader PID 186 — Read object has no parsed kernels

Output 11 directly reads path ID 186 from `sharedassets0.assets`. UnityPy reports:

- Name: `Read`
- Variant[0]: `Kernels=0`
- Variant[1]: `Kernels=0`

Therefore, the earlier PID 186 name match is **not** sufficient to identify a usable parsed compute shader containing `read2DC3`. The output provides no kernel declarations, thread-group sizes, resource bindings, or kernel code. The relationship between `CBUtility.readSdr` and this serialized object remains unproven; the Readback kernel implementation and the 12-byte destination element layout remain unresolved.

### 30.4 Serialized pass-to-program blob ordering

Output 11 inspects the first SubShader's serialized passes and reports these mappings:

| Shader | Path ID | Serialized pass | Vertex blob index | Fragment blob index |
|---|---:|---:|---:|---:|
| Ceto/Fourier | 178 | 0–7 | 0 | 1–8 respectively |
| Ceto/DisplacementCopy | 181 | 0–4 | 0 | 1–5 respectively |
| Ceto/FoamCopy | 150 | 0–3 | 0 | 1–4 respectively |

This confirms the serialized pass order and the fragment-program BlobIndex for each pass. It strengthens the pass-order audit from Outputs 7–9. It does not, by itself, decode the fragment programs or assign world-axis/grid semantics to their channels.

### 30.5 Updated evidence status

| Item | Status after Output 11 |
|---|---|
| CPU query-array creation | Confirmed: four source grids are wrapped into four destination arrays |
| CPU query-array copying | Confirmed: all four grid Data arrays are copied |
| Query-array dimensions/wrapping | Confirmed: source[0].SX used for both dimensions; wrap true |
| Per-entry channel validation | Only source[0].Channels is checked in the shown methods |
| PID 186 Read compute kernels | Not recovered: both parsed variants report zero kernels |
| PID 186 as CBUtility.readSdr | Unproven; name-only match is insufficient |
| Fourier serialized pass order | Confirmed: passes 0–7 map to fragment BlobIndex 1–8 |
| DisplacementCopy serialized pass order | Confirmed: passes 0–4 map to fragment BlobIndex 1–5 |
| FoamCopy serialized pass order | Confirmed: passes 0–3 map to fragment BlobIndex 1–4 |
| Readback 12-byte element layout | Still unresolved |
| Fourth-grid GPU readback | Still not shown by the supplied ReadFromGPU excerpt |

### 30.6 Next evidence required

1. Trace the actual serialized Shader/ComputeShader reference assigned to `CBUtility.readSdr`; do not rely on the name `Read` or PID 186 alone.
2. Recover the readback kernel source from the correct asset/program representation, if present, and identify its output buffer element type.
3. Inspect the declaration and allocation of `m_readBuffer`, plus the exact storage type of `InterpolatedArray2f.Data`, to resolve the 12-byte stride.
4. Trace the CPU and GPU `DisplacementBuffer` query paths side by side, especially how grid 3 is populated when GPU readback only shows three grids.
5. Use the newly confirmed serialized BlobIndex order when joining the C# pass calls to the already extracted Fourier, DisplacementCopy, and FoamCopy program payloads.

**Evidence boundary:** Output 11 closes the four-grid CPU copy-helper behavior and verifies serialized pass-to-blob ordering for three Ceto shaders. It also weakens the earlier PID 186 Read candidate: the parsed object exposes zero kernels in both variants. It does not resolve the readback shader identity, kernel body, 12-byte data structure, or fourth-grid GPU path.

## 31. Raw Output 11 archive

- [Output 11](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%2011) — original terminal output containing the four-grid QueryDisplacements copy helpers, PID 186 Read ComputeShader inspection, and serialized pass/fragment BlobIndex tables.
