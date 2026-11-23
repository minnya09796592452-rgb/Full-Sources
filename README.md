# CASTAWAY-DEPTHS — Full Sources

## Mission: Original Ocean Source Reconstruction

**Primary target:** Reconstruct the original Stranded Deep Ocean system from its available compiled C# source, Unity assets, shaders, compute shaders, materials, textures, and runtime data. Trace the implementation down to low-level formulas and data flow, then map the original calculations faithfully into Godot.

**Rendering scope for this first plan:** Use Godot's lighting temporarily. Do not expand this phase into reproducing the original atmosphere, sun, moon, or lighting system. Ocean is the only primary target until the project owner defines the next phase.

**Core rule:** No guessing presented as fact. Every claim must be classified as confirmed, cross-verified, partial, mismatched, or not yet verified.

---

## 1. Roles and workflow

### Project owner
- Drives the extraction scripts and decides the investigation direction.
- Runs scripts in the current Termux/Python environment and supplies terminal output.
- Leads the Godot-side reconstruction.

### Verification and documentation
- Inspect each supplied output against the original source evidence.
- Identify missing files, methods, data dependencies, and verification requirements.
- Distinguish source facts from inference and unverified assumptions.
- Maintain this repository's audit trail and update the documentation.

The extraction scripts are authored and driven by the project owner. Verification and source-gap analysis are the primary review responsibilities.

---

## 2. Original game environment already identified

| Item | Current finding | Status |
|---|---|---|
| Unity version | `2021.2.7f1` from `Stranded_Deep_Data/globalgamemanagers` | Confirmed |
| Main managed assembly | `Stranded_Deep_Data/Managed/Assembly-CSharp.dll` | Confirmed |
| Ocean system | Ceto, version `1.1.3` | Confirmed in decompiled source |
| Launcher | .NET C# launcher, not the Unity game runtime | Confirmed |
| Launcher PE machine | `0x14c` (x86) | Confirmed |
| Launcher runtime markers | `mscoree.dll`, `_CorExeMain` | Confirmed |

Known working locations on the Android/Termux device:

```text
/storage/emulated/0/Download/Stranded-Deep-Original/
├── Stranded Deep/
│   └── Stranded_Deep_Data/
│       └── Managed/
│           └── Assembly-CSharp.dll
├── ORIGINAL_FORMULAS_SOURCE/
└── DXVK_TRANSLATION_DUMP/
    └── ACTIVE_LIT_SHADERS_FULL/
        └── decompiled_shaders/
```

These are the paths reported during the investigation; verify them on-device before running scripts.

---

## 3. Ocean source inventory discovered so far

The following Ceto classes were found in the managed assembly's class listing:

- `Ocean`
- `WaveSpectrum`
- `WaveSpectrumCondition`
- `WaveSpectrumConditionKey`
- `UnifiedSpectrum`
- `UnifiedSpectrumCondition`
- `UnifiedSpectrumConditionKey`
- `UnifiedPhillipsSpectrumCondition`
- `PhillipsSpectrum`
- `FourierCPU`
- `FourierGPU`
- `FourierTask`
- `SpectrumTask`
- `InitSpectrumDisplacementsTask`
- `DisplacementBufferCPU`
- `DisplacementBufferGPU`
- `WaveSpectrumBuffer`
- `WaveSpectrumBufferCPU`
- `WaveSpectrumBufferGPU`
- `WaveQuery`
- `WaveQueryTask`
- `CoroutineWaveQueryTask`
- `ThreadedWaveQueryTask`
- `QueryDisplacements`
- `QueryGridScaling`
- `WaveOverlay`
- `WaveOverlayData)
- `AddWaveOverlay`
- `AddWaveOverlayBase)
- `CustomWaveSpectrumCondition)

**Important:** Class discovery is not proof that every class is active at runtime. The actual call chain, condition selection, and execution paths still need to be traced.

---

## 4. Confirmed Ocean configuration and parameters

The decompiled `WaveSpectrum` source shows these defaults:

| Parameter | Value |
|---|---:|
| Fourier size | `MEDIUM_64_CPU` |
| Number of grids | `4` |
| Disable readback | `true` |
| Choppyness | `0.8` |
| Foam amount | `1.0` |
| Foam coverage | `0.1` |
| Wind speed | `8` |
| Wave age | `0.64` |
| Wave speed | `1` |
| Grid scale | `0.5` |
| Wave smoothing | `2` |
| Slope smoothing | `1` |
| Foam smoothing | `2` |

Limits found in the same source:

- `MAX_CHOPPYNESS = 1.2`
- `MAX_FOAM_AMOUNT = 6`
- `MAX_FOAM_COVERAGE = 0.5`
- `MAX_WIND_SPEED = 30`
- `MIN_WAVE_AGE = 0.5`
- `MAX_WAVE_AGE = 1`
- `MAX_WAVE_SPEED = 10`
- `MIN_GRID_SCALE = 0.1`
- `MAX_GRID_SCALE = 1)
- Wave, slope, and foam smoothing limits were found with minimum `1` and maximum `6`.

Other Ceto constants/defaults found in `Ocean`:

- `MAX_SPECTRUM_WAVE_HEIGHT = 40f`
- `MAX_OVERLAY_WAVE_HEIGHT = 20f)
- Specular roughness `0.2`
- Specular intensity `0.2`
- Fresnel power `5`
- Minimum Fresnel `0.02`
- Ceto version `1.1.3`

The Ocean source also references reflection, refraction, depth, ocean-depth, ocean-mask, normal-fade, foam, and wave-overlay resources. Exact resource formats and runtime assignments are not yet fully audited.

---

## 5. Spectrum formula evidence

### 5.1 PhillipsSpectrum — method body recovered

The decompiled `PhillipsSpectrum.Spectrum(float kx, float kz)` method was recovered.

Source constants and setup:

```text
GRAVITY = 9.818286
AMP = 0.02
L = WindSpeed * WindSpeed / GRAVITY
length2 = L * L
dampedLength2 = length2 * (0.001 * 0.001)
```

The wind direction is converted from degrees to a 2D unit vector. The wave vector is rotated into wind-relative coordinates, then the method computes the wave-number magnitude. Values below `1E-06` return zero.

Equivalent mathematical form of the recovered method:

```text
P(k) = 0.02
       * exp(-1 / (k^2 * L^2))
       / k^4
       * (k'x / k)^6
       * exp(-k^2 * Ld^2)
```

where `k'x` is the wind-relative normalized x component and `Ld^2 = L^2 * 0.001^2).

**Status:** Formula body recovered from decompiled source. It is **not yet confirmed** that this is the spectrum selected by the active Stranded Deep runtime condition.

### 5.2 UnifiedSpectrum — incomplete

The decompiled class exposes constants/fields including:

- `GRAVITY = 9.818286`
- `WAVE_CM = 0.23`
- `WAVE_KM = 370`
- `U10`, `G_SQ_OMEGA_U10`, `Z_SQ_U10_G`
- `SIGMA`, `ALPHA_P`, `kp`, `cp`, `z0`, `u_star`, `gamma`
- `alpham`, `am`, `WindSpeed`, `WaveAge`, `WindDir`

The complete constructor and `Spectrum()` method have not yet been reviewed.

**Status:** Partial. Do not implement this formula from field names alone.

---

## 6. WaveSpectrum initialization and data structures

The reviewed section of `WaveSpectrum.cs` exposes:

- Displacement maps: `m_displacementMaps`
- Slope maps: `m_slopeMaps`
- Foam maps: `m_foamMaps`
- Displacement, slope, and Jacobian buffers
- A readback `ComputeBuffer`
- Grid sizes and choppyness vectors
- A scheduler, spectrum conditions, condition cache, and query scaling object

The `Start()` method was observed to:

1. Set global slope/displacement/foam textures to black textures.
2. Create slope, displacement, and foam copy materials.
3. Create slope and displacement initialization materials.
4. Create the foam initialization material using `initJacobianSdr`.
5. Create a scheduler.
6. Call `CreateBuffers()`.
7. Call `CreateRenderTextures()`.
8. Call `CreateConditions()`.
9. Call `UpdateQueryScaling()`.

The source also exposes `IsCreatingNewCondition`, which checks whether `m_conditions[1]` is non-null when the conditions array exists.

**Status:** Initialization order and field names confirmed. Buffer contents, formats, update order, and method internals remain to be inspected.

---

## 7. Weather-to-Ocean parameter changes

The decompiled `OceanWeatherEventEffect` source shows fields for `WaveAge`, `WindSpeed`, and `FoamAmount`.

Observed behavior:

- Saves the previous spectrum values when initializing the effect.
- Interpolates wind speed toward the target and rounds it to increments of `0.05`.
- Interpolates wave age and rounds it to increments of `0.02`.
- Interpolates foam amount without the same quantization.
- Avoids changing the values while the spectrum is creating a new condition.
- Restores the saved values when the effect ceases.

**Status:** Behavior recovered from the reviewed method body. Full weather-condition creation and all callers still need tracing.

---

## 8. Ocean shader evidence

The decompiled shader file reviewed:

`sharedassets0.assets_175_Ceto_OceanTopSide_Transparent.shader`

Observed references include:

- `Ceto_DisplacementMap1`
- `Ceto_DisplacementMap2`
- `Ceto_FoamTexture0`
- `Ceto_FoamTexture1`
- `Ceto_OceanDepth0`
- `Ceto_OceanDepth1`
- `Ceto_GridScale`
- `Ceto_Choppyness`
- `Ceto_MapSize`
- `Ceto_WaveSmoothing`
- `Ceto_PosOffset`
- `Ceto_SpecularIntensity`
- `Ceto_SpecularRoughness)
- `Ceto_ScreenGridSize)
- `Ceto_Overlay_HeightMap)

The shader samples displacement maps with `textureLod()`. This confirms that displacement textures are consumed by the ocean shader, but does not yet establish the complete texture packing, coordinate mapping, or generation pipeline.

---

## 9. Current Ocean data-flow model

The working hypothesis to verify is:

```text
Ocean configuration / weather parameters
                 |
                 v
       Spectrum condition selection
                 |
                 v
       Spectrum frequency-domain data
                 |
                 v
          Fourier processing
                 |
                 v
       Displacement / slope / Jacobian
                 |
                 v
        Foam and render-texture passes
                 |
                 v
       Global textures and uniforms
                 |
                 v
       Ceto Ocean vertex/fragment shader
```

This is a **working investigation map**, not yet a fully verified execution graph. Each arrow must be tied to actual method calls and data writes.

---

## 10. Required investigation work

### A. Source and asset inventory
- Enumerate every Ceto class and method from the assembly.
- Extract complete method bodies for all Ocean-related classes.
- Identify all Ceto shader assets, compute shaders, materials, textures, and serialized references.
- Record assembly metadata and source/decompiler provenance.
- Find all callers and references for the Ocean entry points.

### B. Spectrum and random initialization
- Recover the complete `UnifiedSpectrum` constructor and `Spectrum()`.
- Inspect `UnifiedSpectrumCondition`, `UnifiedPhillipsSpectrumCondition`, and related keys.
- Determine which spectrum condition is actually selected.
- Trace random seed generation and initial spectrum values.
- Recover grid frequencies, wave-vector generation, and all normalization factors.

### C. Fourier processing
- Inspect complete `FourierCPU`, `FourierGPU`, and `FourierTask` method bodies.
- Determine transform direction, algorithm, iteration order, normalization, precision, and threading behavior.
- Inspect compute shader kernels and dispatch dimensions if present.
- Verify whether the configured `MEDIUM_64_CPU` path is actually used in the target runtime.

### D. Displacement, slope, Jacobian, and foam
- Inspect `InitSpectrumDisplacementsTask` and `SpectrumTask`.
- Inspect CPU/GPU displacement buffer implementations.
- Trace displacement channel meaning and coordinate conventions.
- Recover slope and Jacobian calculations.
- Recover foam generation, persistence, smoothing, and copy passes.
- Trace condition transitions and cache behavior.

### E. Render textures and shader interface
- Record every texture's resolution, format, channel layout, filter, wrap, mipmap, and update timing.
- Trace every global texture and uniform from producer to consumer.
- Recover ocean vertex displacement, normals, foam, depth, Fresnel, reflection/refraction, and specular calculations.
- Inspect all relevant shader variants, not only the top-side transparent shader.

### F. Wave queries and overlays
- Inspect `WaveQuery`, query tasks, `QueryDisplacements`, and `QueryGridScaling`.
- Trace CPU/GPU readback and world-to-grid coordinate conversion.
- Inspect overlay height, displacement, and blending paths.

### G. Godot parity mapping
For each recovered operation, document:
- Original source location and method.
- Inputs, outputs, constants, data types, units, coordinate system.
- Operation order and precision-sensitive details.
- Texture/buffer format and channel packing.
- Godot equivalent and any unavoidable API differences.
- A test or comparison that can demonstrate numerical/visual parity.

Do not silently replace original formulas with visually similar approximations.

---

## 11. Verification status snapshot

| Area | Status |
|---|---|
| Unity version / managed assembly identification | Confirmed |
| Ceto version and Ocean class presence | Confirmed |
| WaveSpectrum defaults and limits | Confirmed |
| Phillips Spectrum formula body | Recovered; runtime selection unverified |
| Unified Spectrum formula | Partial |
| WaveSpectrum initialization sequence | Confirmed |
| Fourier class discovery | Confirmed; implementations not reviewed |
| Displacement/slope/foam fields | Confirmed; generation not reviewed |
| Ocean shader displacement sampling | Confirmed |
| Full producer-to-consumer data flow | Not yet verified |
| Full Ocean shader formula reconstruction | Not yet verified |
| Exact Godot numerical parity | Not yet tested |

---

## 12. Scope boundary

**Included now:** Original Ocean source and asset investigation, low-level formula recovery, shader/compute-shader analysis, texture and buffer mapping, and faithful Godot Ocean reconstruction.

**Temporary choice:** Use Godot's lighting for this phase.

**Excluded from this first phase:** Reconstructing the original Atmosphere, Sun/Moon, sky, or complete lighting system; terrain, foliage, gameplay, save/load, and unrelated systems. These can be planned only after the project owner closes the Ocean phase and gives the next direction.

---

## 13. Evidence and change log

Every new finding should record:
- Date/time and extraction command or script name.
- Original file/asset and method or shader name.
- Relevant source excerpt or extracted artifact path.
- Exact finding and verification status.
- Dependencies and unresolved questions.
- Related Godot mapping or test, if any.

Never mark a subsystem complete merely because its class, file, or shader name was found. Completion requires the relevant data path and formulas to be traced and verified.

### Investigation history carried into this repository
- Ocean/Ceto class discovery and initial parameter extraction.
- Phillips Spectrum formula recovery.
- Unified Spectrum constants discovery.
- WaveSpectrum initialization and buffer/texture field discovery.
- Ocean top-side transparent shader displacement and foam sampling discovery.
- Weather-driven WindSpeed, WaveAge, and FoamAmount interpolation behavior.

**Mission principle:** Original source first. Low-level evidence. Formula fidelity. Godot mapping. No unsupported claims.


---

## 14. Latest extraction audit — Output #49

Source record: [Output directory at commit `6ae2c0c4f1ae0fdaa2368cb9d1c8e7d0c390a62c`](https://github.com/minnya09796592452-rgb/Full-Sources/tree/6ae2c0c4f1ae0fdaa2368cb9d1c8e7d0c390a62c/Output)

### 14.1 C# source inventory

The extraction command reported **103 matching C# paths** for its Ocean/Ceto search:

```bash
find "$CLEAN_OUT/CSharp_Scripts" -iname "*ocean*" -o -path "*/Ceto/*" -name "*.cs" | sort -u
```

The seven requested core files were all found under `ORIGINAL_SOURCES_CLEAN/CSharp_Scripts/Ceto/`:

- `FourierCPU.cs`
- `FourierGPU.cs`
- `UnifiedSpectrum.cs`
- `WaveSpectrum.cs`
- `PhillipsSpectrum.cs`
- `QueryDisplacements.cs`
- `ProjectedGrid.cs`

**Qualification:** 103 is the result of that particular search expression, not yet a verified count of every Ceto source file. The `find` expression should be parenthesized in a future definitive inventory to make the intended filter unambiguous.

### 14.2 Execution-path evidence from source references

The grep output confirms the following in the reviewed files:

- `WaveSpectrum` owns a `fourierSdr` Shader reference and exposes its displacement buffer through `DisplacementBuffer`.
- `CreateBuffers()` has a CPU branch constructing `DisplacementBufferCPU(size, m_scheduler)` and a GPU branch constructing `DisplacementBufferGPU(size, fourierSdr)`.
- The same method constructs GPU slope and Jacobian buffers using `fourierSdr`.
- `WaveSpectrum` references `SpectrumTask` through condition task creation.
- It publishes slope, displacement, and foam textures through Unity global shader texture assignments.
- Displacement buffer textures are passed into the displacement-copy material before being assigned to global displacement maps.

This is stronger evidence for the producer-to-render-texture path, but the grep excerpt alone does not prove the complete call order or the internal numerical operations. Full method bodies and callers still need review.

### 14.3 Unity asset shader inventory

The parsed-name scan reported these Ceto Shader assets in `sharedassets0.assets`:

| Path ID | Shader |
|---:|---|
| 139 | `Ceto/OceanBottom` |
| 142 | `Ceto/OceanMaskFlipped` |
| 143 | `Ceto/OceanUnderSide_Transparent` |
| 147 | `Ceto/SlopeCopy` |
| 150 | `Ceto/FoamCopy` |
| 154 | `Ceto/InitDisplacement` |
| 155 | `Ceto/CopyDepth` |
| 159 | `Ceto/InitJacobians` |
| 160 | `Ceto/NormalFade` |
| 161 | `Ceto/WaveOverlay` |
| 166 | `Ceto/BlurEffectConeTap` |
| 168 | `Ceto/OceanMask` |
| 175 | `Ceto/OceanTopSide_Transparent` |
| 176 | `Ceto/InitSlope` |
| 178 | `Ceto/Fourier` |
| 179 | `Ceto/OceanDepth` |
| 181 | `Ceto/DisplacementCopy` |

Additional water-related shaders reported in `resources.assets`:

- `Beam Team/Post Effects/Underwater` (path ID 3077)
- `Beam Team/Post Effects/Water Distort and Droplets` (path ID 3144)

### 14.4 ComputeShader result — important distinction

The parsed-name scan found ComputeShader objects with IDs 186–198, but their names were:

`Read`, `Histogram`, `Texture3DLerp`, `AutoExposure`, `MultiScaleVORender`, `Lut3DBaker`, `MultiScaleVODownsample1`, `MultiScaleVOUpsample`, `GaussianDownsample`, `ExposureHistogram`, `Waveform`, `Vectorscope`, and `MultiScaleVODownsample2`.

The `Waveform` ComputeShader is a post-processing/debug waveform tool, not evidence of a Ceto Ocean Fourier compute shader. The Ceto Fourier asset found here is a regular Unity **Shader** named `Ceto/Fourier` (path ID 178). Therefore, the current evidence points to Ceto's Fourier GPU path using a Shader/material pass, not a ComputeShader kernel. This must still be checked against the complete `FourierGPU.cs` and serialized material references.

### 14.5 Updated verification status

| Area | Updated status |
|---|---|
| Core Ceto source files | Seven named files found |
| Ocean/Ceto source count | 103 search matches; definitive inventory still needed |
| WaveSpectrum CPU/GPU buffer selection | Branch and constructors visible in grep output |
| Fourier GPU asset | `Ceto/Fourier` Shader found |
| Ceto-specific ComputeShader | Not identified in this scan |
| Ocean render/copy/init shaders | Multiple named Ceto Shader assets found |
| Full Fourier implementation | Not yet reviewed |
| Serialized shader-to-field assignment | Not yet verified |
| Full numerical execution chain | Not yet verified |

### 14.6 Next evidence required

1. Review the complete `FourierGPU.cs`, `FourierCPU.cs`, and `WaveSpectrum.CreateBuffers()` / update methods.
2. Extract the complete `Ceto/Fourier` shader source and inspect its passes, properties, vertex/fragment programs, and transform stages.
3. Inspect serialized Ceto materials/components to establish which shader asset is assigned to `fourierSdr` in the actual game.
4. Trace the condition task into spectrum initialization and Fourier execution, then follow the resulting buffers into slope/Jacobian/displacement and copy passes.
5. Confirm whether the runtime uses the CPU or GPU branch; the default `MEDIUM_64_CPU` setting alone is not enough to establish the selected runtime path.

**Evidence boundary:** This update records only what is visible in Output #49. It does not claim that the Ocean source extraction or execution-chain reconstruction is complete.


---

## 15. Fourier implementation audit — Output 2

Source record: [Output 2 at commit `84cc353b465586d39f93675364c08ef9e1406da8`](https://github.com/minnya09796592452-rgb/Full-Sources/tree/84cc353b465586d39f93675364c08ef9e1406da8/Output%202)

### 15.1 FourierGPU — confirmed implementation structure

The complete `FourierGPU.cs` output shows:

- Constructor rejects sizes that are not powers of two.
- Number of stages is `log2(size)`.
- It creates one butterfly lookup texture per stage.
- Lookup textures are `size × 1`, `RGBAFloat`, no mip chain, linear, point-filtered, clamp-wrapped.
- The lookup stores two source indices (normalized by `size - 1`) and cosine/sine twiddle values.
- The first stage uses bit-reversed input indices; later stages use direct stage indices.
- The GPU transform is implemented by repeated `Graphics.Blit` / `RTUtility.MultiTargetBlit` calls through the `Ceto/Fourier` material, not by a Ceto-named ComputeShader in the asset inventory.
- Transform passes are split into two loops: first the X-axis stages, then the Y-axis stages.
- Overloads support one, two, three, or four data texture groups, using shader pass indices 0–7 respectively.
- Multi-target overloads check `SystemInfo.supportedRenderTargetCount` before running.
- The method returns the final ping-pong buffer index; it returns `-1` if the butterfly lookup table has been released.

**Not yet established:** shader pass arithmetic, sign convention, inverse/forward interpretation, normalization, texture channel semantics, and whether the game selects this GPU path at runtime.

### 15.2 FourierCPU — confirmed implementation structure

The complete `FourierCPU.cs` output shows:

- The same power-of-two size validation and `log2(size)` stage count.
- A CPU butterfly lookup table with source indices `j1`, `j2` and twiddle components `wr`, `wi`.
- The first stage uses bit-reversed indices; subsequent stages use direct indices.
- Two-dimensional processing is performed as two stage groups: one dimension followed by the other.
- `PeformFFT_SinglePacked` transforms the complex value stored in Vector4.x/y.
- `PeformFFT_DoublePacked` transforms two complex values in Vector4.xy and Vector4.zw.
- Both routines ping-pong between two data arrays according to `startIdx`.
- Both check the cancellation token inside the inner loops and return `-1` if cancelled.
- The routines return the final active ping-pong index.

The visible butterfly arithmetic combines the first input with the twiddle-multiplied second input. The complete source excerpt does not by itself settle the intended transform direction or normalization convention.

### 15.3 Fourier Shader asset — parsed structure only

The UnityPy output identifies `Ceto/Fourier` at `sharedassets0.assets` path ID 178. Its parsed form contains one SubShader with **8 passes**. Pass names and tags were empty in the displayed parsed output.

This matches the eight pass indices used by `FourierGPU` (0–7), but the actual shader program bodies were not printed in Output 2. Therefore the match is a strong structural correspondence, not yet a verified mathematical pass-by-pass mapping.

### 15.4 Serialized reference scan — provisional only

A raw-byte scan reported MonoBehaviour objects at path IDs 333 and 438 containing the byte sequence corresponding to little-endian int32 value 178.

This is **not proof** that either component's `fourierSdr` field references Shader path ID 178: an arbitrary byte sequence can occur elsewhere in serialized data. The next check must parse the MonoBehaviour serialized fields/PPtrs and resolve the exact object reference, including file ID and path ID.

### 15.5 Updated status

| Area | Status |
|---|---|
| FourierGPU algorithm structure | Reviewed from complete C# output |
| FourierCPU single/double packed routines | Reviewed from complete C# output |
| Butterfly lookup construction | Confirmed in CPU and GPU source |
| 2D X/Y stage organization | Confirmed in CPU and GPU source |
| GPU shader pass count | 8 parsed passes; indices correspond structurally to calls 0–7 |
| Fourier shader arithmetic | Not yet extracted/reviewed |
| Transform sign / direction / normalization | Not yet verified |
| Serialized `fourierSdr` assignment | Raw-byte candidates only; unverified |
| Runtime CPU vs GPU selection | Not yet verified |

### 15.6 Next evidence required

1. Extract the actual `Ceto/Fourier` shader source/program data for all eight passes.
2. Parse MonoBehaviour path IDs 333 and 438 as serialized objects and inspect exact PPtr fields; do not rely on raw-byte occurrence.
3. Inspect `FourierTask`, `SpectrumTask`, `InitSpectrumDisplacementsTask`, and the CPU/GPU buffer callers to establish which Fourier overload is called and with what packed data.
4. Trace transform inputs and outputs, then determine sign, normalization, axis orientation, and channel packing from both C# and shader code.
5. Verify runtime CPU/GPU selection from serialized component values and actual initialization conditions.

**Evidence boundary:** Output 2 confirms the CPU/GPU butterfly FFT structures and the eight-pass Fourier shader asset. It does not yet provide the shader's arithmetic or prove which serialized component assigns it to `fourierSdr`.



---

## 16. Fourier task, spectrum initialization, and shader-reference audit — Output 3

Source record: [Output 3 at commit `99eaa324e40cf9bc4fbc3be4727c476c32fa2470`](https://github.com/minnya09796592452-rgb/Full-Sources/tree/99eaa324e40cf9bc4fbc3be4727c476c32fa2470/Output%203)

### 16.1 FourierTask — CPU execution and result packing

The displayed `FourierTask.cs` confirms:

- It is a threaded task and accepts a `WaveSpectrumBufferCPU`, `FourierCPU`, buffer index, and grid count.
- It obtains the selected buffer's data arrays, result pixels, Texture2D map, and `doublePacked` flag.
- `Run()` calls `PerformSingleFourier()`; the transform selects `PeformFFT_SinglePacked` or `PeformFFT_DoublePacked` according to `doublePacked`.
- A non-cancelled transform is required to finish in read-buffer index 1; otherwise it throws an exception.
- `End()` uploads results using `SetPixels()` and `Apply()`.
- `ProcessData()` maps Vector4 components into Color channels and writes displacement data for 1–4 grids. The write pattern differs by buffer index and grid count, with horizontal/vertical displacement contributions accumulated into the interpolated displacement arrays.

**Source anomaly to re-check:** the constructor checks `m_index == -1` before assigning `m_index = index`. That means the check observes the field's initial/default value rather than the constructor argument. Record this as a decompiled-code observation; verify against the original assembly/IL before treating it as an intentional guard or behavior.

### 16.2 InitSpectrumDisplacementsTask — confirmed initialization math

The displayed source confirms:

- The task captures `NumGrids`, `Size`, `SpectrumType`, `TimeValue`, and the CPU displacement buffer from the supplied condition.
- It allocates spectrum arrays and a frequency/time table, with the second spectrum array allocated when more than two grids are used.
- It obtains three read buffers and configures each buffer's `doublePacked` mode according to the number of grids.
- When `condition.LastUpdated` changes, it copies the condition's `SpectrumData01`, `SpectrumData23`, and `WTableData` into the task's local arrays.
- The task dispatches to separate initialization routines for one, two, three, or four grids.
- For each grid cell, normalized coordinates are converted to signed wrapped coordinates using the 0.5 threshold; the mirrored index is `(size-j)%size + ((size-i)%size)*size`.
- The initialization combines paired spectrum coefficients with time-dependent cosine/sine terms. Multi-grid paths pack multiple complex components into Vector4 channels.
- The `CreateKTables()` method builds per-grid wave-vector tables from signed grid coordinates and inverse grid sizes, and stores reciprocal wave-number magnitude (zero when magnitude is zero).
- The shown displacement-related terms multiply the complex result by wave-vector components and reciprocal magnitude to construct directional components.

**Not yet established:** full mathematical interpretation of each packed channel, exact physical units, spectrum source selection, and parity of every 1–4 grid branch. Those require tracing all task callers and the corresponding shader/data consumers.

### 16.3 Ceto/Fourier shader — program metadata and symbols

The UnityPy parse of `sharedassets0.assets` path ID 178 reports eight fragment subprogram entries:

- Pass 0 → BlobIndex 1
- Pass 1 → BlobIndex 2
- Pass 2 → BlobIndex 3
- Pass 3 → BlobIndex 4
- Pass 4 → BlobIndex 5
- Pass 5 → BlobIndex 6
- Pass 6 → BlobIndex 7
- Pass 7 → BlobIndex 8

All eight entries report `m_GpuProgramType = 17` in the extraction output. The raw Shader object also contains these embedded symbols: `Ceto_ButterFlyLookUp`, `Ceto_ReadBuffer0`, `Ceto_ReadBuffer1`, `Ceto_ReadBuffer2`, and `Ceto_ReadBuffer3`.

This strengthens the link between the eight FourierGPU passes and the shader's four read-buffer inputs plus butterfly lookup. It still does **not** reveal the actual GPU instruction/program arithmetic, transform sign, or normalization. Blob indices are metadata, not decoded shader source.

### 16.4 Exact serialized PPtr matches — verified references, field semantics pending

The revised scan checks the serialized PPtr byte pattern using both file ID and path ID, and reports these MonoBehaviour references to Shader path ID 178:

| Asset file | MonoBehaviour path ID | File ID | Shader path ID |
|---|---:|---:|---:|
| `level0` | 313 | 2 | 178 |
| `level2` | 271 | 4 | 178 |
| `level3` | 1250 | 3 | 178 |
| `level4` | 5585 | 3 | 178 |

These are exact serialized PPtr-pattern matches to the external Shader object, unlike the earlier raw int32 search. However, the output does not decode the MonoBehaviour type/field name or prove that the PPtr occupies the specific `fourierSdr` field. The component type and serialized field layout must still be parsed to establish that semantic assignment.

### 16.5 Updated verification status

| Area | Status |
|---|---|
| FourierTask CPU call selection | Confirmed: single/double packed selected by buffer flag |
| FourierTask output buffer expectation | Confirmed: expects final index 1 when not cancelled |
| FourierTask displacement channel writes | Visible for 1–4 grid cases; full channel semantics still need mapping |
| InitSpectrumDisplacementsTask time evolution | Cosine/sine combination of paired spectrum coefficients confirmed |
| Signed wrapped grid coordinates and mirrored index | Confirmed in displayed code |
| Per-grid wave-vector tables | Confirmed; reciprocal magnitude stored |
| Fourier shader subprogram count | Eight entries, BlobIndex 1–8 |
| Fourier shader embedded symbols | Butterfly lookup and four read-buffer symbols found |
| Serialized references to Shader PID 178 | Exact PPtr-pattern matches in level0/2/3/4 MonoBehaviours |
| PPtr field identified as `fourierSdr` | Not yet proven; component/field parsing required |
| Shader arithmetic, transform direction, normalization | Not yet recovered |
| Runtime CPU/GPU selection | Not yet verified |

### 16.6 Next evidence required

1. Decode the four referenced MonoBehaviour objects' script/type identity and serialized fields; establish whether the PPtr to path ID 178 is specifically `fourierSdr`.
2. Decode the eight GPU program blobs for `Ceto/Fourier` and map each program to the corresponding pass and buffer count.
3. Trace `SpectrumTask` and all callers of `InitSpectrumDisplacementsTask` and `FourierTask`, including scheduling, reset, cancellation, and buffer-index transitions.
4. Build an explicit channel map for 1-, 2-, 3-, and 4-grid output, connecting `ProcessData()` to the later displacement texture and ocean shader consumers.
5. Verify the apparent `FourierTask` constructor guard against original IL because the field is checked before the argument is assigned.

**Evidence boundary:** Output 3 adds concrete CPU task and spectrum-initialization behavior, eight Fourier GPU program metadata entries, and exact PPtr-pattern matches to Shader PID 178. It does not yet prove the serialized field name, decode shader arithmetic, or establish the runtime-selected CPU/GPU route.

---

## 17. Raw extraction output archive

The original root-level output files have been collected under [`Outputs/`](https://github.com/minnya09796592452-rgb/Full-Sources/tree/main/Outputs) so later extraction records stay grouped and easy for scripts to consume:

- [Output 1](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%201.txt)
- [Output 2](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%202.txt)
- [Output 3](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%203.txt)

These are raw terminal-output records; the README sections above are the human-readable audit. Keep future raw outputs in `Outputs/Output N.txt` and continue appending verified findings here.


---

## 18. Fourier GPU program extraction audit — Output 4

Source record: [Output 4 at commit `07bad70be68c6a29c501714242f8212167153b2d`](https://github.com/minnya09796592452-rgb/Full-Sources/tree/07bad70be68c6a29c501714242f8212167153b2d/Outputs/Output%204)

### 18.1 Original IL resolves the FourierTask constructor anomaly

The Output 4 IL excerpt confirms the constructor reads `m_index` before it assigns the supplied `index` argument:

- `IL_0008`: load `m_index`
- `IL_000d`: compare with `-1`
- `IL_0010`: throw if equal
- The shown excerpt then continues at `IL_001b` to process the buffer argument.

Because this is a newly constructed object's integer field, it is initially zero unless initialized otherwise. Therefore the guard does **not** validate the constructor's `index` argument. This is now confirmed in the supplied IL excerpt, not merely a decompiler display quirk. The later assignment location should still be inspected in the remaining IL to document the full constructor sequence.

### 18.2 Extracted shader program artifacts

The extraction decompresses `sharedassets0.assets` Shader path ID 178 (`Ceto/Fourier`) from its compressed blob using LZ4 and saves two platform payloads:

| Platform | Extracted file | Size | Marker scan |
|---|---|---:|---|
| 4 | `Ceto_Fourier_plat4_seg0.bin` | 10,624 bytes | 9 occurrences of `DXBC` |
| 15 | `Ceto_Fourier_plat15_seg0.bin` | 29,060 bytes | 16 occurrences of `#version` |
| 15 | `Ceto_Fourier_plat15_seg0_GLSL.txt` | 29,088 bytes | Latin-1 text dump containing GLSL sections and binary metadata |

The platform 15 dump includes readable GLSL fragment programs. The platform 4 binary contains DXBC markers, but Output 4 does not disassemble or map the DXBC chunks to individual passes. The marker count alone is not a count of shader passes or proof of nine distinct complete programs.

### 18.3 GLSL fragment arithmetic — first pass family decoded

The readable platform 15 GLSL sections expose the butterfly operation. For each input texture, the shader:

1. Samples `Ceto_ButterFlyLookUp` to obtain two source coordinates and twiddle components.
2. Samples the first source coordinate from each `Ceto_ReadBufferN` texture.
3. Forms the twiddle product from the sampled complex pairs. The emitted components include the real/imaginary multiply terms using the lookup's cosine/sine pair.
4. Samples the second source coordinate and adds it to the twiddled first-source result.
5. Writes one output render target per input read buffer.

The GLSL uses packed RGBA values: the arithmetic operates on two complex pairs in the RG and BA lanes. The exact interpretation of those pairs as displacement/slope/Jacobian channels must be connected to the C# buffer packing and downstream consumers before assigning physical meaning.

The extracted text contains the one-buffer, two-buffer, three-buffer, and four-buffer fragment variants, with the number of read samplers and output render targets increasing accordingly. Each variant has an X-coordinate and Y-coordinate form; the coordinate selection differs between those forms, matching the two-axis FFT stages in `FourierGPU`.

**Important limitation:** the shown GLSL is a translated platform-15 representation. It provides readable arithmetic, but transform sign/direction and normalization still depend on the actual lookup values, stage ordering, and any scaling outside this shader. No normalization multiply is visible in the displayed butterfly fragment arithmetic itself.

### 18.4 Updated verification status

| Area | Status |
|---|---|
| FourierTask constructor guard | Confirmed by supplied IL: field checked before argument assignment |
| Platform 4 shader payload | Extracted binary with DXBC markers; disassembly not supplied |
| Platform 15 shader payload | Extracted payload and GLSL text dump |
| Butterfly lookup sampling | Confirmed in readable GLSL |
| Two-source butterfly combine | Confirmed in readable GLSL |
| Packed RGBA complex arithmetic | Confirmed structurally in GLSL operations |
| 1–4 read-buffer/output variants | Present in extracted GLSL text |
| X/Y coordinate variants | Present; coordinate selection differs by axis |
| Exact channel-to-physical-field mapping | Not yet verified |
| Transform sign/direction | Not yet fully established |
| Normalization/scaling across full pipeline | Not yet verified |
| DXBC-to-pass mapping | Not yet established |

### 18.5 Next evidence required

1. Parse the GLSL dump into clean, separately named fragment variants and map each to pass indices 0–7 using the C# pass constants and sampler/output counts.
2. Disassemble the platform-4 DXBC payload and compare its arithmetic with the platform-15 GLSL variants.
3. Decode butterfly lookup texture generation into explicit coordinate/twiddle equations, then combine with the shader arithmetic to determine transform sign and stage convention.
4. Trace all scale factors before and after Fourier execution to establish normalization.
5. Connect the RG/BA complex lanes and each read-buffer index to the exact grid/displacement/slope/Jacobian data structures and render-texture consumers.

**Evidence boundary:** Output 4 provides readable GLSL for the Fourier butterfly and raw DXBC payload extraction. It materially advances shader arithmetic recovery, but does not yet establish the full transform convention, scaling, or complete data-channel semantics.

---

## 19. Raw Output 4 archive

- [Output 4.txt](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%204.txt) — original terminal output archived alongside Outputs 1–3.
- [Fourier DXBC/GLSL blobs](https://github.com/minnya09796592452-rgb/Full-Sources/tree/main/Outputs/Fourier_DXBC_Blobs) — extracted platform payloads and readable GLSL dump.



## 20. Output 5 — Butterfly lookup equations and initialization shader audit

Source: [Outputs/Output 5](https://github.com/minnya09796592452-rgb/Full-Sources/blob/84a33d339d85ba3a9b954b37f363e82bf8a31bb1/Outputs/Output%205)

### 20.1 Butterfly lookup generation — C# evidence

The Output 5 excerpt exposes the core of `FourierCPU.ComputeButterflyLookupTable()`:

- For stage `i`, it computes `num = 2^(passes-1-i)` and `num2 = 2^i`.
- For each butterfly pair, the unpermuted source indices are `num3 = j*num2*2+k` and `num4 = j*num2*2+num2+k`.
- Stage 0 applies `BitReverse()` to both source indices; later stages use the direct indices.
- Twiddle components are generated as `wr = cos(2π*k*num/fsize)` and `wi = sin(2π*k*num/fsize)`.
- The lookup entry is stored at `num3 + i*size`, with `j1`, `j2`, `wr`, and `wi`.

This confirms the lookup's index and twiddle construction in the displayed CPU source. It does **not**, by itself, prove the final transform sign convention or normalization; those depend on how the butterfly consumes the twiddle and how the pipeline scales its outputs.

### 20.2 InitDisplacement — Shader PID 154

The extracted platform-15 GLSL declares `Ceto_Offset`, `Ceto_InverseGridSizes`, `Ceto_Time`, `Ceto_Spectrum01`, and `Ceto_WTable`.

Observed operations:

1. Convert each texture coordinate component from the upper half of [0,1] to a negative wrapped coordinate, then multiply by the inverse grid size.
2. Sample `Ceto_Spectrum01` at `Ceto_Offset - uv` and at `uv`, using LOD 0.
3. Form component-wise sum and difference of those two samples.
4. Sample `Ceto_WTable`; multiply its red component by `Ceto_Time`; evaluate sine and cosine.
5. Combine the sum/difference values with sine/cosine into a two-component intermediate.
6. Write that intermediate to `SV_Target0.xy`; derive two additional components using the wrapped wave-vector coordinates and reciprocal wave-vector magnitude, with a zero-magnitude guard, and write them to `SV_Target0.zw`.

The shader output component roles are not yet tied to named runtime buffer fields, so do not label them as specific physical displacement axes without the consumer-side mapping.

### 20.3 InitSlope — Shader PID 176

This shader uses the same wrapped-coordinate construction, spectrum pair sampling, sum/difference, WTable time phase, and sine/cosine combination as InitDisplacement. It then multiplies the intermediate by the wrapped coordinate components and writes the resulting two-component derivative-like values to `SV_Target0.xy`; `SV_Target0.zw` is explicitly zero.

This is direct evidence of a slope-initialization shader variant, but the exact world-axis convention and downstream channel interpretation still require tracing the texture consumers and render-target setup.

### 20.4 InitJacobians — Shader PID 159

The GLSL additionally declares `Ceto_FoamAmount`. It:

- constructs three wrapped/inverse-grid coordinate terms;
- forms a normalized coordinate-derived vector with a zero-length guard;
- samples the mirrored and direct spectrum coordinates and multiplies both sample pairs by `Ceto_FoamAmount`;
- samples WTable and computes the time phase using sine/cosine;
- writes a scalar derived from the spectrum/time combination multiplied across the constructed vector into `SV_Target0`.

The visible shader output establishes the calculation structure, but not the final Jacobian determinant interpretation or foam-generation meaning. Those require matching the shader output to the actual target format and later consumers.

### 20.5 Updated evidence status

| Item | Status after Output 5 |
|---|---|
| Butterfly source-index pairing | Confirmed in displayed FourierCPU source |
| Stage-0 bit reversal vs later direct indexing | Confirmed in displayed source |
| Twiddle cosine/sine construction | Confirmed in displayed source |
| InitDisplacement spectrum pairing and time-phase arithmetic | Extracted from PID 154 GLSL |
| InitSlope derivative-like output arithmetic | Extracted from PID 176 GLSL |
| InitJacobians coordinate/spectrum/time arithmetic | Extracted from PID 159 GLSL |
| Exact physical meaning of output channels | Still unverified |
| Exact Jacobian determinant / foam interpretation | Still unverified |
| Full Fourier sign convention and normalization | Still unverified |
| Runtime texture formats, bindings, and consumer mapping | Still required |

### 20.6 Next evidence required

1. Trace the C# call sites that bind `Ceto_Spectrum01`, `Ceto_WTable`, `Ceto_Offset`, `Ceto_InverseGridSizes`, `Ceto_Time`, and `Ceto_FoamAmount` for each initialization material.
2. Extract the render-texture creation descriptors and confirm formats, dimensions, filtering, wrapping, and which shader writes each target.
3. Trace the resulting displacement, slope, and Jacobian textures into their copy/readback and ocean-material consumers to establish exact channel semantics.
4. Inspect the complete InitJacobians shader variants/passes and the downstream foam calculation before assigning a mathematical Jacobian/foam formula.
5. Continue Fourier normalization and sign analysis by combining the confirmed lookup equations with the complete GPU/CPU butterfly execution and all pre/post scale factors.

**Evidence boundary:** Output 5 adds concrete C# butterfly lookup equations and three initialization shader bodies. It advances the source-level reconstruction of displacement, slope, and Jacobian initialization, but does not yet close runtime bindings, output-channel meanings, texture formats, or the full Fourier convention.

## 21. Raw Output 5 archive

- [Output 5](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%205) — original terminal output for the butterfly lookup and initialization-shader extraction.


## 22. Output 6 — GPU buffer lifecycle, render-texture formats, and WaveSpectrum consumers

Source: [Outputs/Output 6](https://github.com/minnya09796592452-rgb/Full-Sources/blob/658c8306c6899fbc7493a859ede3861522ebf7b5/Outputs/Output%206)

### 22.1 WaveSpectrumBufferGPU structure and initialization bindings

The extracted `WaveSpectrumBufferGPU` source establishes:

- Constructor accepts 1–4 logical buffers and creates a `FourierGPU` instance.
- Each logical buffer owns a two-slot `RenderTexture[]` ping-pong pair.
- `GetTexture(idx)` returns black if no valid Fourier result exists, the index is out of range, or that buffer is disabled; otherwise it returns the current ping-pong slot.
- Initialization binds `Ceto_Spectrum01`, `Ceto_Spectrum23`, `Ceto_WTable`, `Ceto_InverseGridSizes`, `Ceto_GridSizes`, `Ceto_Offset`, and `Ceto_Time` to the selected init material.
- The active destination textures are populated by `Graphics.Blit` for one target or `RTUtility.MultiTargetBlit` for two to four targets.
- `Run()` allocates/recreates the enabled ping-pong textures, runs initialization, then invokes the matching 1–4-buffer FourierGPU overload.
- Sampling changes the final active texture from Point/Clamp to Bilinear/Repeat; disabling sampling restores Point/Clamp.

The constructor's offset is `(1 + 0.5/Size, 1 + 0.5/Size, 0, 0)`. The excerpt confirms this literal value; its precise texel-center rationale should be checked against the shader coordinate convention before reimplementing it.

### 22.2 GPU temporary texture descriptors

The `CreateTextures()` method obtains temporary textures using:

- Dimensions: `Size × Size`
- Depth buffer: 0
- Format: `RenderTextureFormat.ARGBFloat`
- Read/write: `RenderTextureReadWrite.Linear`
- Filter: Point
- Wrap: Clamp
- Anisotropic level: 0
- Name: `Ceto Wave Spectrum GPU Buffer`

These are the Fourier/init ping-pong textures. Their sampling mode is changed only for the final result while consumers sample it.

### 22.3 DisplacementBufferGPU

The GPU displacement buffer uses exactly three logical buffers. It creates one `InterpolatedArray2f` per `QueryDisplacements.GRIDS`, each with dimensions `size × size`, `QueryDisplacements.CHANNELS` channels, and wrapping enabled. Query/copy/range operations delegate to `QueryDisplacements`.

This establishes a three-buffer GPU displacement path, but the physical meaning of each buffer and the interpolated-array channels still need the `QueryDisplacements` copy/query implementation and copy-shader pass mapping.

### 22.4 WaveSpectrum shader bindings and buffer routing

The displayed `WaveSpectrum.cs` excerpt shows:

- Slope generation chooses init pass `numGrids - 1`, runs the slope GPU buffer, enables sampling, copies buffer 0 into slope map 0, and copies buffer 1 into slope map 1 only when `numGrids > 2`; otherwise slope map 1 is set to black. For `numGrids <= 2`, slope buffer 1 is disabled.
- Displacement generation enables/disables logical buffers according to displacement enablement and choppyness. When choppyness is zero, buffers 1 and 2 are disabled; when positive, both are enabled. For `numGrids <= 2`, buffer 2 is disabled.
- Displacement init also selects pass `numGrids - 1`. It copies buffer 0 as the height source and buffers 1/2 as displacement sources through `displacementCopyMat`, using passes 0–4 according to grid index/count.
- The resulting four displacement maps are published as `Ceto_DisplacementMap0..3`; missing maps are explicitly set to black.
- After copying, GPU readback is conditionally invoked only when the existing readback path allows it; the excerpt shows the call site but not the full `ReadFromGPU()` implementation.

### 22.5 Persistent map descriptors and buffer allocation

The displayed buffer creation and `CreateRenderTextures()` code establishes:

- GPU displacement buffer: 3 logical buffers.
- Slope buffer: 2 logical buffers.
- Jacobian buffer: 3 logical buffers.
- Readback compute buffer allocation: `size * size` elements with stride 12.
- Persistent maps: 4 displacement, 2 slope, and 1 foam render textures.
- All persistent maps use `RenderTextureFormat.ARGBFloat`, `RenderTextureReadWrite.Linear`, dimensions `size × size`, depth 0, Trilinear filtering, Repeat wrapping, anisotropic level 9, and mipmaps enabled.

The output shows allocation of the Jacobian buffer, but does not include the complete Jacobian generation/consumer method. It also does not show the actual texture format/stride interpretation of the readback data beyond the compute-buffer stride value.

### 22.6 Updated evidence status

| Item | Status after Output 6 |
|---|---|
| GPU buffer count range and ping-pong layout | Confirmed: 1–4 buffers, two texture slots each |
| Init material property binding names | Confirmed in WaveSpectrumBufferGPU source |
| Init target routing | Confirmed: Blit for one target, MultiTargetBlit for 2–4 |
| Temporary Fourier/init texture format | Confirmed: ARGBFloat, Linear, Point, Clamp |
| Final sampling state | Confirmed: Bilinear, Repeat; restored to Point/Clamp afterward |
| GPU displacement buffer count | Confirmed: 3 |
| Slope / Jacobian GPU buffer counts | Confirmed: 2 / 3 |
| Persistent map counts | Confirmed: displacement 4, slope 2, foam 1 |
| Persistent map descriptor | Confirmed: ARGBFloat, Linear, Trilinear, Repeat, mipmaps, aniso 9 |
| Displacement and slope copy routing | Partially confirmed from WaveSpectrum call sites |
| Exact RGBA component meanings | Still unverified |
| Jacobian generation/foam consumer mapping | Still unverified from this output |
| QueryDisplacements channel semantics | Still requires source inspection |
| Readback element interpretation | Still requires ReadFromGPU and copy implementation |

### 22.7 Next evidence required

1. Inspect the complete `QueryDisplacements.cs` implementation, especially `CopyAndCreateDisplacements`, `CopyDisplacements`, `MaxRange`, and `QueryWaves`, to map the three GPU buffers to query channels and physical axes.
2. Extract all `DisplacementCopy`, `SlopeCopy`, and foam/Jacobian shader variants and map their pass indices to the C# call sites, including the special displacement pass 4.
3. Trace the Jacobian buffer's initialization, sampling, copy, and foam-map consumer path; Output 6 only shows its allocation.
4. Inspect the full `ReadFromGPU()` implementation and ComputeBuffer read shader to establish the 12-byte element layout and readback semantics.
5. Match `Spectrum23` binding and `GridSizes` usage against the relevant init shader variants/passes; the displayed PID 154/176/159 GLSL excerpt alone does not establish every pass's sampler usage.

**Evidence boundary:** Output 6 establishes concrete GPU buffer allocation, ping-pong behavior, temporary and persistent render-texture descriptors, init-material property bindings, and displacement/slope routing. It does not yet establish exact channel-to-world-axis semantics, Jacobian-to-foam flow, or GPU readback layout.

## 23. Raw Output 6 archive

- [Output 6](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%206) — original terminal output containing the GPU buffer classes, WaveSpectrum call sites, and render-texture descriptors.


## 24. Output 7 — displacement, slope, and foam copy shader audit

Source: [Output 7](https://github.com/minnya09796592452-rgb/Full-Sources/blob/224df9603527d9e7fc1b89315ce1e605616d741c/Outputs/Output%207)

### 24.1 Shader assets recovered

The extraction selected three Unity Shader assets from `sharedassets0.assets` and decompressed their platform-15 payloads:

| Shader | Path ID | Extracted fragment variants |
|---|---:|---:|
| `Ceto/SlopeCopy` | 147 | 1 |
| `Ceto/FoamCopy` | 150 | 4 |
| `Ceto/DisplacementCopy` | 181 | 5 |

These are readable GLSL fragment programs translated from the platform-15 shader payload. The output does not include the corresponding C# call-site excerpt, so the exact pass-index-to-fragment-index mapping must still be cross-checked against `WaveSpectrum.cs` and the shader's serialized pass order.

### 24.2 SlopeCopy — direct texture copy

The single fragment declares `Ceto_SlopeBuffer`, samples it at `vs_TEXCOORD0.xy`, and writes the sampled RGBA value unchanged to `SV_Target0`.

This establishes a direct sample-and-copy shader body. It does not itself perform slope differentiation or smoothing; those operations, if any, occur upstream or in other passes.

### 24.3 DisplacementCopy — explicit channel routing

All five fragments sample one or two source textures and write a four-component destination:

| Fragment | Destination X | Destination Y | Destination Z | Destination W |
|---:|---|---|---|---|
| 0 | DisplacementBuffer.x | HeightBuffer.x | DisplacementBuffer.y | 0 |
| 1 | DisplacementBuffer.z | HeightBuffer.y | DisplacementBuffer.w | 0 |
| 2 | DisplacementBuffer.x | HeightBuffer.z | DisplacementBuffer.y | 0 |
| 3 | DisplacementBuffer.z | HeightBuffer.w | DisplacementBuffer.w | 0 |
| 4 | HeightBuffer.z | HeightBuffer.x | HeightBuffer.w | 0 |

The table records literal GLSL component routing; it deliberately does not assign world-axis names to X/Y/Z or infer which grid each fragment represents. Fragment 4 is structurally distinct: it samples only `Ceto_HeightBuffer` and writes its `z, x, w` components into destination `xyz`.

This output provides the shader-side half of the channel map. To close the mapping, match each fragment to the exact `displacementCopyMat` pass selected for each grid count and then trace the source buffer channels back to their initialization/Fourier producers.

### 24.4 FoamCopy — multi-buffer polynomial combination

All four fragments declare `Ceto_FoamChoppyness` and `Ceto_FoamCoverage`. They sample one, two, or three Jacobian-buffer textures depending on the variant and write a scalar/vector result with unused trailing channels set to zero in the lower-count variants.

- Fragment 0 samples `Ceto_JacobianBuffer0` and combines its `x,y,z` components with the scalar choppyness component and foam coverage. Its final scalar includes a negative squared term derived from the scaled `z` component.
- Fragment 1 samples Jacobian buffers 0 and 1. It uses choppyness `xy`, combines buffer-0 `xy/zw` lanes, and applies a final negative squared term derived from buffer 1 `xy`.
- Fragment 2 samples buffers 0, 1, and 2, uses choppyness `xyz`, and writes three result components. Each component combines the corresponding values from the three sampled buffers and a negative squared term from buffer 2.
- Fragment 3 is the four-component form: it samples buffers 0, 1, and 2, performs component-wise operations using `Ceto_FoamChoppyness`, adds `Ceto_FoamCoverage`, and writes the resulting vec4.

The extracted arithmetic confirms that foam-copy output is built from Jacobian-buffer samples, choppyness, and coverage. It does **not** by itself establish the semantic names of the Jacobian channels or prove the physical interpretation of the resulting scalar/vector as a particular determinant or foam persistence model.

### 24.5 Updated evidence status

| Item | Status after Output 7 |
|---|---|
| SlopeCopy fragment body | Confirmed: direct RGBA sample/copy |
| DisplacementCopy fragment count | Confirmed: five variants |
| DisplacementCopy source-to-destination component routing | Confirmed literally for fragments 0–4 |
| Special single-source fragment 4 | Confirmed |
| FoamCopy fragment count | Confirmed: four variants |
| FoamCopy Jacobian sampler count | Confirmed: one, two, or three samplers across variants |
| FoamCopy dependence on choppyness and coverage | Confirmed |
| Exact pass-index-to-fragment mapping | Not yet cross-verified |
| Channel-to-world-axis / grid meaning | Not yet verified |
| Jacobian channel semantics and full foam model | Not yet verified |
| Slope generation math | Not provided by SlopeCopy; upstream init/generation still needs tracing |

### 24.6 Next evidence required

1. Re-open the complete `WaveSpectrum.cs` copy call sites and map each `displacementCopyMat.SetPass(...)` index to the corresponding shader fragment in the serialized pass order.
2. Extract the C# foam-copy invocation and map its selected pass to the one-, two-, three-, and four-component FoamCopy variants.
3. Trace each Jacobian buffer's initialization shader output and Fourier lanes into the exact sampler/channel consumed by FoamCopy.
4. Join the displacement-copy component routing with `QueryDisplacements.cs` and the ocean shader's displacement-map sampling to assign grid, axis, and channel semantics without guessing.
5. Inspect any slope-map consumers and smoothing passes separately; the SlopeCopy fragment itself is only a direct copy.

**Evidence boundary:** Output 7 establishes the readable copy-shader arithmetic and explicit component routing. It advances the buffer/channel audit, but does not independently establish pass ordering, world-axis labels, Jacobian semantics, or the complete foam-generation pipeline.

## 25. Raw Output 7 archive

- [Output 7](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%207) — original terminal output containing the platform-15 GLSL fragments for SlopeCopy, FoamCopy, and DisplacementCopy.


## 26. Output 8 — displacement copy pass mapping, query channels, and GPU readback

Source: [Output 8](https://github.com/minnya09796592452-rgb/Full-Sources/blob/b88650d28807d3a215c1f106cadfbfee0c76dcdc/Outputs/Output%208)

### 26.1 WaveSpectrum.GenerateDisplacement — C# pass mapping

Output 8 provides the relevant `WaveSpectrum.cs` call sites and closes the pass-selection gap left by Output 7:

- The displacement init material uses pass `numGrids - 1`.
- Buffer 0 is bound as `Ceto_HeightBuffer`; buffer 1 is initially bound as `Ceto_DisplacementBuffer`.
- For displacement map 0, the copy pass is **4 when there is exactly one grid**, otherwise pass **0**.
- Displacement map 1 uses pass **1** when grid 1 exists.
- Before map 2, `Ceto_DisplacementBuffer` is rebound to logical buffer 2; map 2 uses pass **2**.
- Map 3 uses pass **3** when grid 3 exists.
- Missing maps are explicitly assigned the black texture.
- Sampling is enabled before the copy operations and disabled afterward; `BeenSampled` is then set.
- If the displacement buffer is GPU-backed, `ReadFromGPU(numGrids)` is called after the map copies, followed by `FindRanges()`.

This maps the C# selected pass numbers to the five DisplacementCopy fragment variants by matching the pass index with the extracted fragment ordering. The source excerpt does not independently expose Unity's serialized pass metadata, so the pass-index/fragment-index identity remains a strong direct correlation, not a separately inspected serialized pass table.

### 26.2 QueryDisplacements.Sample — query output channel use

The supplied `QueryDisplacements.cs` excerpt shows four grid slots and their per-grid inverse-size scaling:

- Grid 0 uses `scaling.invGridSizes.x`.
- Grid 1 uses `scaling.invGridSizes.y`.
- Grid 2 uses `scaling.invGridSizes.z`.
- Grid 3 uses `scaling.invGridSizes.w`.

For each enabled grid, `Sample()` computes sample coordinates from world/query `x,z`, samples the corresponding `InterpolatedArray2f`, then assigns:

- `result[0]` to output displacement `d[grid].x`, multiplied by the grid's choppyness component.
- `result[1]` to output height `d[grid].y`, multiplied by `scaling.scaleY`.
- `result[2]` to output displacement `d[grid].z`, multiplied by the grid's choppyness component.

`SampleHeightOnly()` reads the same grid-specific sample but uses only `result[1]` for output height, scaled by `scaleY`.

This confirms the query-array channel-to-output-vector mapping: channels 0, 1, and 2 feed output X, Y, and Z respectively. It does not alone prove the upstream render-texture RGBA packing that populated those three query-array channels; that bridge still needs the complete copy/read implementation.

### 26.3 ReadFromGPU — conditional readback path

The shown method establishes the complete readback gate:

- If readback is requested (`disableReadBack == false`) but `readSdr` is null, it logs a warning.
- Actual readback requires all of:
  - `disableReadBack == false`
  - `readSdr != null`
  - `m_readBuffer != null`
  - graphics shader level at least 5.0
  - compute-shader support
- For each available grid, `CBUtility.ReadFromRenderTexture(map, 3, m_readBuffer, readSdr)` is called, then `m_readBuffer.GetData(readDisplacements[grid].Data)`.
- Missing grid slots are cleared.
- The excerpt only shows grids 0–2 explicitly; it does not show a fourth readback operation.

This confirms readback is optional and compute-capability-gated. The output does not include `CBUtility.ReadFromRenderTexture`, the read shader body, or the exact `ComputeBuffer` element struct, so the 12-byte stride's field layout remains unverified.

### 26.4 FindRanges — GPU/no-readback fallback

When `disableReadBack` is true and the displacement buffer is GPU-backed, `FindRanges()` assigns `MaxDisplacement = (0, 40 * gridScale)`. Otherwise it schedules a `FindRangeTask` when no task exists or the prior task is complete.

The fallback is a fixed source-level range assignment; it is not evidence that the actual frame's displacement extrema were measured on the GPU.

### 26.5 GenerateSlopes — confirmed call-site behavior

The same Output 8 excerpt confirms:

- Slopes are disabled when the graphics shader level is below 3.0, with a warning.
- If disabled, all slope buffers are disabled and both global slope maps are set to black.
- With active slopes, buffer 1 is disabled when `numGrids <= 2`.
- The init pass is `numGrids - 1`.
- Buffer 0 is copied to slope map 0 with SlopeCopy pass 0.
- Buffer 1 is copied to slope map 1 only when `numGrids > 2`; otherwise map 1 is black.
- The buffer's sampling state is restored after the copy.

This joins the direct-copy shader body from Output 7 to the actual C# slope-map call sites.

### 26.6 Updated evidence status

| Item | Status after Output 8 |
|---|---|
| DisplacementCopy selected pass numbers | Confirmed in C# call sites: map0 uses 4 for one grid, else 0; maps1–3 use 1–3 |
| Height/displacement source-buffer binding | Confirmed for buffers 0, 1, and 2 |
| QueryDisplacements result channel mapping | Confirmed: result[0/1/2] → output X/Y/Z |
| Per-grid query coordinate scaling | Confirmed: inverse grid size x/y/z/w for grids 0–3 |
| Query displacement choppyness scaling | Confirmed per grid on output X and Z |
| Query height scaling | Confirmed through `scaleY` |
| GPU readback capability gate | Confirmed from method body |
| Readback data layout / 12-byte stride fields | Still unverified |
| Query-array channel ↔ render-texture source RGBA bridge | Still requires full copy/read implementation |
| Fourth-grid GPU readback | Not shown in supplied excerpt |
| Foam generation invocation/body | Not included in the supplied Output 8 excerpt |

### 26.7 Next evidence required

1. Inspect the complete `DisplacementBufferGPU` and `QueryDisplacements.CopyAndCreateDisplacements/CopyDisplacements` bodies to connect the render-texture channels to `InterpolatedArray2f` channels 0–2.
2. Recover `CBUtility.ReadFromRenderTexture`, the read shader, and the exact ComputeBuffer element type to resolve the 12-byte layout.
3. Extract the remainder of `WaveSpectrum.GenerateFoam()` and its call sites, including the foam-copy material pass selection and foam-map publication.
4. Verify the shader's serialized pass ordering if the asset metadata is available, rather than relying only on fragment extraction order.
5. Trace the four-grid CPU query path separately from GPU readback, since the shown GPU readback body explicitly handles only three map slots.

**Evidence boundary:** Output 8 materially links C# displacement/slope call sites to the copy shader variants and establishes query output channel usage and the GPU readback gate. It still does not fully connect the copied RGBA render textures to the three query-array channels, decode the readback struct, or expose the foam-generation body.

## 27. Raw Output 8 archive

- [Output 8](https://github.com/minnya09796592452-rgb/Full-Sources/blob/main/Outputs/Output%208) — original terminal output containing WaveSpectrum generation/readback call sites and QueryDisplacements sampling code.
