

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
