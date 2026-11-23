

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


## 34. Output 14 — ComputeBuffer stride confirmation and four-grid readback boundary

Source: [Output 14](https://github.com/minnya09796592452-rgb/Full-Sources/blob/be37f5f72ab5577bea47ee9556150cb0f850fb7d/Outputs/Output%2014)

### 34.1 Exact managed GPU readback allocation

The supplied WaveSpectrum.cs grep output locates the actual allocation:

    m_readBuffer = new ComputeBuffer(size * size, 12);

This confirms the managed ComputeBuffer has size * size elements and a **12-byte stride per element**. This matches read2DC3's three 32-bit output words per pixel (3 × 4 bytes) and the three-channel InterpolatedArray2f.Data layout. The kernel's floatBitsToInt conversion writes the sampled float bit patterns into integer words; the managed array receives those payloads through GetData.

The output does not include a runtime sample or numerical comparison, so this is a source-level layout match, not independent runtime validation of values.

### 34.2 Readback path and exact grid coverage

The WaveSpectrum.ReadFromGPU excerpt shows:

- Grid 0: ReadFromRenderTexture(m_displacementMaps[0], 3, m_readBuffer, readSdr), then GetData(readDisplacements[0].Data).
- Grid 1: same operation for map 1 and array 1.
- Grid 2: same operation for map 2 and array 2.
- After grid 2, the method contains the literal _ = 3; no map 3 dispatch or GetData(readDisplacements[3].Data) appears in the supplied excerpt.

The same Output 14 prints QueryDisplacements.GRIDS = 4 and CHANNELS = 3. QueryWaves requires exactly four displacement arrays, and the shown query code sums entries 0, 1, 2, and 3 for height and horizontal displacement.

**Confirmed boundary:** the CPU query layer is structured for four grids, while the supplied GPU readback method explicitly copies only the first three maps. Output 14 does not establish where or whether the fourth array is populated by another path. Do not assume it is populated, intentionally zero, or unused without tracing the remaining producer/consumer paths.

### 34.3 Read ComputeShader kernel thread-group inventory

Output 14 enumerates all 12 kernels from the last variant's lowercase kernels field and prints their thread-group sizes:

| Kernel group | Kernels | Thread-group size |
|---|---|---|
| 2D channel reads | read2DC1, read2DC2, read2DC3, read2DC4 | 8×8×1 |
| 2D single reads | readSingle2D, readSingleBilinear2D | 1×1×1 |
| 3D channel reads | read3DC1, read3DC2, read3DC3, read3DC4 | 8×8×8 |
| 3D single reads | readSingle3D, readSingleBilinear3D | 1×1×1 |

The printed excerpts show the channel-read kernels use texelFetch and floatBitsToInt; the bilinear single-read variants use textureLod with a linear-clamp sampler. This records the shader operations visible in the output without inferring additional filtering semantics.

### 34.4 Updated evidence status

| Item | Status after Output 14 |
|---|---|
| Managed m_readBuffer element count | Confirmed: size * size |
| Managed ComputeBuffer stride | Confirmed: 12 bytes |
| Three-channel GPU output width | Confirmed: three 32-bit words = 12 bytes/pixel |
| GPU output width vs managed stride | Exact source-level match |
| GPU output width vs CPU float[] channel storage | Width matches three 32-bit channels; bit-pattern path shown by floatBitsToInt |
| Runtime numeric readback validation | Not supplied |
| CPU query grid count | Confirmed: 4 |
| GPU ReadFromGPU explicit map copies | Confirmed: maps 0, 1, and 2 only in supplied method excerpt |
| Fourth-grid array producer/population | Unresolved |
| 2D/3D kernel thread groups | Confirmed from printed variant inventory |

### 34.5 Remaining evidence targets

1. Trace all writes to readDisplacements[3] and all call sites that can populate the fourth CPU query array.
2. Inspect the complete ReadFromGPU method and its callers to establish whether another branch handles grid 3 outside the shown excerpt.
3. Recover the exact CBUtility.ReadFromRenderTexture kernel-selection and dispatch code alongside each channel count to map all 2D read variants.
4. If runtime access becomes available, compare known texture float values against returned float[] values to validate bit-preserving transfer end to end.

**Evidence boundary:** Output 14 confirms the exact 12-byte managed ComputeBuffer stride and the three-grid readback shown in ReadFromGPU. It does not explain the fourth grid's CPU-array population, nor does it provide runtime numerical validation.

## 35. Raw Output 14 archive

- [Output 14](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%2014) — terminal evidence for the exact ComputeBuffer allocation, four-grid query declarations, readback calls, and 2D/3D Read kernel thread-group inventory.
