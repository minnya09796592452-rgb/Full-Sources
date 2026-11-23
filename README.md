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
