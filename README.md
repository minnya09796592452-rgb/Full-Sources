

## 32. Output 12–13 — InterpolatedArray2f storage and Read shader identity

Source: [Output 12–13](https://github.com/minnya09796592452-rgb/Full-Sources/blob/c572d94ee211c05ef18fe01bdd36113df0538152/Outputs/Output%2012%20-%2013)

### 32.1 InterpolatedArray2f — storage layout

The complete supplied class shows that `InterpolatedArray2f.Data` is a `float[]`. Its backing array length is:

`SX * SY * Channels`

The indexer and Get/Set methods use interleaved channel-major-per-pixel indexing:

`(x + y * SX) * Channels + channel`

For each pixel, all channel values are contiguous. The constructor taking an existing `float[]` allocates a same-sized backing array and copies the input into it. The class also exposes `SX`, `SY`, and `Channels`.

This confirms the CPU query-array element storage is 32-bit float data, with channels interleaved for each pixel. The displayed interpolation method performs bilinear interpolation over the four neighboring samples; coordinate conversion depends on `HalfPixelOffset`.

### 32.2 WaveSpectrum.readSdr → ComputeShader PID 186 reference

Output 12–13 examines the serialized `WaveSpectrum` MonoBehaviour at `level2` path ID 271. Searching its raw bytes for the serialized PPtr pair `fileID=4, pathID=186` returns true at offset 180. In the context of the inspected assets, this supports the reference from that WaveSpectrum object to `sharedassets0.assets` path ID 186.

Combined with Output 11's PID 186 object name `Read`, this is substantially stronger than the earlier name-only match and supports identifying PID 186 as the referenced Read ComputeShader candidate. The raw-byte search is the evidence supplied here; a decoded named-field PPtr printout was not included, so retain that qualification.

### 32.3 Read ComputeShader kernel inventory

The re-inspected typetree exposes two variants. Both list the following kernels:

- `read2DC1`, `read2DC2`, `read2DC3`, `read2DC4`
- `readSingle2D`, `readSingleBilinear2D`
- `read3DC1`, `read3DC2`, `read3DC3`, `read3DC4`
- `readSingle3D`, `readSingleBilinear3D`

The earlier Output 11 zero-kernel result came from reading the `m_Kernels` key, while this output reads the parsed typetree's lowercase `kernels` key. The later output therefore corrects the earlier inspection method; it does not mean the asset changed.

### 32.4 read2DC3 — recovered GLSL kernel

For variant 1, the `read2DC3` kernel's `variantMap` provides GLSL with:

- Local workgroup size: `8 × 8 × 1`
- Input sampler: `sampler2D _Tex2D`
- Output storage buffer: `_Buffer2DC3`
- Output element structure: `uint[3] value`
- Bounds guard: global invocation X < `_Width`, Y < `_Height`
- Linear destination index: `y * _Width + x`
- Source read: `texelFetch(_Tex2D, ivec2(x,y), 0).xyz`
- Conversion: `floatBitsToInt` for the three sampled float components, then each 32-bit bit pattern is written into the three uint slots.

The shader therefore writes three 32-bit words per pixel, i.e. 12 bytes per output element. This matches the three-channel readback dispatch selected by Output 9's `CBUtility.ReadFromRenderTexture` call site and explains the observed 12-byte stride at the shader-output level.

**Important distinction:** The GLSL declares the destination words as `uint[3]`, while `InterpolatedArray2f.Data` is a `float[]`. The kernel uses `floatBitsToInt`, which preserves each sampled float's bit pattern in a 32-bit integer word. The supplied output does not show the C# `ComputeBuffer` allocation declaration/stride or a runtime readback test, so the exact managed buffer declaration remains to be independently verified even though the GPU payload width and float-array storage width now align.

### 32.5 Updated evidence status

| Item | Status after Output 12–13 |
|---|---|
| InterpolatedArray2f backing storage | Confirmed: float[] |
| Per-pixel channel layout | Confirmed: interleaved, index `(x + y*SX)*Channels + c` |
| WaveSpectrum PID 186 reference | Supported by raw serialized PPtr byte-pair match at offset 180; decoded field-level proof not printed |
| Read ComputeShader kernel inventory | Confirmed from lowercase `kernels` typetree field; 12 kernel names per variant |
| read2DC3 workgroup size | Confirmed: 8×8×1 |
| read2DC3 source sampling | Confirmed: texelFetch at integer pixel coordinates, mip 0 |
| read2DC3 output structure | Confirmed: three 32-bit uint words per pixel |
| 12-byte GPU output element width | Confirmed: 3 × 4-byte words |
| GPU word ↔ CPU float bit-pattern compatibility | Supported by `floatBitsToInt` and float[] storage; managed ComputeBuffer declaration/runtime transfer still to verify |
| Fourth-grid GPU readback | Still not shown; ReadFromGPU explicitly reads maps 0–2 |

### 32.6 Next evidence required

1. Extract the remaining read kernels, especially `read2DC1/2/4` and the single-channel variants, to compare their output layouts and filtering behavior.
2. Decode the WaveSpectrum MonoBehaviour's named PPtr fields and identify exactly which field points to PID 186, rather than relying only on the raw byte-pair match.
3. Recover the C# `ComputeBuffer` constructor/allocation line for `m_readBuffer`, including count, stride, and element type.
4. Trace why GPU readback reads only displacement maps 0–2 while CPU query arrays and copy helpers support four grids.
5. Confirm the readback data ordering with an actual runtime sample or a fully traced buffer copy path before assigning physical meaning to the three channels.

**Evidence boundary:** Output 12–13 recovers the Read kernel inventory and the actual three-channel read2DC3 GLSL body. It establishes a 12-byte, three-word GPU output per pixel and the float[] CPU query storage. The exact managed ComputeBuffer declaration and fourth-grid GPU handling remain open.

## 33. Raw Output 12–13 archive

- [Output 12–13](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%2012%20-%2013) — original terminal output containing InterpolatedArray2f, WaveSpectrum-to-Read reference check, Read kernel inventory, and read2DC3 GLSL.
