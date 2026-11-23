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

