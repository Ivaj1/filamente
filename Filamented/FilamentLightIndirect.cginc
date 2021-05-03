#ifndef FILAMENT_LIGHT_INDIRECT
#define FILAMENT_LIGHT_INDIRECT

#include "FilamentCommonOcclusion.cginc"
#include "FilamentBRDF.cginc"
#include "UnityImageBasedLightingMinimal.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityLightingCommon.cginc"

//------------------------------------------------------------------------------
// Image based lighting configuration
//------------------------------------------------------------------------------

// Number of spherical harmonics bands (1, 2 or 3)
#define SPHERICAL_HARMONICS_BANDS           3

// IBL integration algorithm
#define IBL_INTEGRATION_PREFILTERED_CUBEMAP         0
#define IBL_INTEGRATION_IMPORTANCE_SAMPLING         1 // Not supported!

#define IBL_INTEGRATION                             IBL_INTEGRATION_PREFILTERED_CUBEMAP

#define IBL_INTEGRATION_IMPORTANCE_SAMPLING_COUNT   64


//------------------------------------------------------------------------------
// IBL prefiltered DFG term implementations
//------------------------------------------------------------------------------

float3 PrefilteredDFG_LUT(float lod, float NoV) {
    // coord = sqrt(linear_roughness), which is the mapping used by cmgen.
    //return textureLod(light_iblDFG, vec2(NoV, lod), 0.0).rgb;
    // Not supported!
    return float3(1.0, 0.0, 0.0); 
}

//------------------------------------------------------------------------------
// IBL environment BRDF dispatch
//------------------------------------------------------------------------------

float3 prefilteredDFG(float perceptualRoughness, float NoV) {
    // PrefilteredDFG_LUT() takes a LOD, which is sqrt(roughness) = perceptualRoughness
    // Not supported yet!
    //return PrefilteredDFG_LUT(perceptualRoughness, NoV);
    #if 1
    // Karis' approximation based on Lazarov's
    const float4 c0 = float4(-1.0, -0.0275, -0.572,  0.022);
    const float4 c1 = float4( 1.0,  0.0425,  1.040, -0.040);
    float4 r = perceptualRoughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
    return (float3(float2(-1.04, 1.04) * a004 + r.zw, 0.0));
    #else
    // Zioma's approximation based on Karis
    return float3(float2(1.0, pow(1.0 - max(perceptualRoughness, NoV), 3.0)), 0.0);
    #endif
}

//------------------------------------------------------------------------------
// IBL irradiance implementations
//------------------------------------------------------------------------------

float3 Irradiance_SphericalHarmonics(const float3 n) {
    /*
    return max(
          frameUniforms.iblSH[0]
#if SPHERICAL_HARMONICS_BANDS >= 2
        + frameUniforms.iblSH[1] * (n.y)
        + frameUniforms.iblSH[2] * (n.z)
        + frameUniforms.iblSH[3] * (n.x)
#endif
#if SPHERICAL_HARMONICS_BANDS >= 3
        + frameUniforms.iblSH[4] * (n.y * n.x)
        + frameUniforms.iblSH[5] * (n.y * n.z)
        + frameUniforms.iblSH[6] * (3.0 * n.z * n.z - 1.0)
        + frameUniforms.iblSH[7] * (n.z * n.x)
        + frameUniforms.iblSH[8] * (n.x * n.x - n.y * n.y)
#endif
        , 0.0);
    */
    return ShadeSH9(float4(n, 1));
}

/*
float3 Irradiance_RoughnessOne(const float3 n) {
    // note: lod used is always integer, hopefully the hardware skips tri-linear filtering
    return decodeDataForIBL(textureLod(light_iblSpecular, n, frameUniforms.iblRoughnessOneLevel));
}
*/

//------------------------------------------------------------------------------
// IBL irradiance dispatch
//------------------------------------------------------------------------------

float3 get_diffuseIrradiance(const float3 n) {
    /* Not implemented.
    if (frameUniforms.iblSH[0].x == 65504.0) {
#if FILAMENT_QUALITY < FILAMENT_QUALITY_HIGH
        return Irradiance_RoughnessOne(n);
#else
        ivec2 s = textureSize(light_iblSpecular, int(frameUniforms.iblRoughnessOneLevel));
        float du = 1.0 / float(s.x);
        float dv = 1.0 / float(s.y);
        float3 m0 = normalize(cross(n, float3(0.0, 1.0, 0.0)));
        float3 m1 = cross(m0, n);
        float3 m0du = m0 * du;
        float3 m1dv = m1 * dv;
        float3 c;
        c  = Irradiance_RoughnessOne(n - m0du - m1dv);
        c += Irradiance_RoughnessOne(n + m0du - m1dv);
        c += Irradiance_RoughnessOne(n + m0du + m1dv);
        c += Irradiance_RoughnessOne(n - m0du + m1dv);
        return c * 0.25;
#endif
        return Irradiance_RoughnessOne(n);
    } else {
        return Irradiance_SphericalHarmonics(n);
    }
    */
        return Irradiance_SphericalHarmonics(n);
}
//------------------------------------------------------------------------------
// IBL specular
//------------------------------------------------------------------------------

UnityGIInput InitialiseUnityGIInput(const ShadingParams shading, const PixelParams pixel)
{
    UnityGIInput d;
    /*
    d.light = light;
    d.atten = atten;
    #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
        d.ambient = 0;
        d.lightmapUV = i_ambientOrLightmapUV;
    #else
        d.ambient = i_ambientOrLightmapUV.rgb;
        d.lightmapUV = 0;
    #endif
    */
    d.worldPos = shading.position;
    d.worldViewDir = -shading.view;
    d.probeHDR[0] = unity_SpecCube0_HDR;
    d.probeHDR[1] = unity_SpecCube1_HDR;
    #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
      d.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
    #endif
    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
      d.boxMax[0] = unity_SpecCube0_BoxMax;
      d.probePosition[0] = unity_SpecCube0_ProbePosition;
      d.boxMax[1] = unity_SpecCube1_BoxMax;
      d.boxMin[1] = unity_SpecCube1_BoxMin;
      d.probePosition[1] = unity_SpecCube1_ProbePosition;
    #endif
    return d;
}

// Workaround: Construct the correct Unity variables and get the correct Unity spec values

inline half3 UnityGI_prefilteredRadiance(const UnityGIInput data, const float3 r, float perceptualRoughness)
{
    half3 specular;

    Unity_GlossyEnvironmentData glossIn;
    glossIn.roughness = perceptualRoughness;
    glossIn.reflUVW = r;

    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
        // we will tweak reflUVW in glossIn directly (as we pass it to Unity_GlossyEnvironment twice for probe0 and probe1), so keep original to pass into BoxProjectedCubemapDirection
        half3 originalReflUVW = glossIn.reflUVW;
        glossIn.reflUVW = BoxProjectedCubemapDirection (originalReflUVW, data.worldPos, data.probePosition[0], data.boxMin[0], data.boxMax[0]);
    #endif

    #ifdef _GLOSSYREFLECTIONS_OFF
        specular = unity_IndirectSpecColor.rgb;
    #else
        half3 env0 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube0), data.probeHDR[0], glossIn);
        #ifdef UNITY_SPECCUBE_BLENDING
            const float kBlendFactor = 0.99999;
            float blendLerp = data.boxMin[0].w;
            UNITY_BRANCH
            if (blendLerp < kBlendFactor)
            {
                #ifdef UNITY_SPECCUBE_BOX_PROJECTION
                    glossIn.reflUVW = BoxProjectedCubemapDirection (originalReflUVW, data.worldPos, data.probePosition[1], data.boxMin[1], data.boxMax[1]);
                #endif

                half3 env1 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0), data.probeHDR[1], glossIn);
                specular = lerp(env1, env0, blendLerp);
            }
            else
            {
                specular = env0;
            }
        #else
            specular = env0;
        #endif
    #endif

    return specular;
}

float perceptualRoughnessToLod(float perceptualRoughness) {
    const float iblRoughnessOneLevel = 1.0/UNITY_SPECCUBE_LOD_STEPS;
    // The mapping below is a quadratic fit for log2(perceptualRoughness)+iblRoughnessOneLevel when
    // iblRoughnessOneLevel is 4. We found empirically that this mapping works very well for
    // a 256 cubemap with 5 levels used. But also scales well for other iblRoughnessOneLevel values.
    return iblRoughnessOneLevel * perceptualRoughness * (2.0 - perceptualRoughness);
}

float3 prefilteredRadiance(const float3 r, float perceptualRoughness) {
    float lod = perceptualRoughnessToLod(perceptualRoughness);
    return (UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, r, lod));
}

float3 prefilteredRadiance(const float3 r, float roughness, float offset) {
    const float iblRoughnessOneLevel = 1.0/UNITY_SPECCUBE_LOD_STEPS;
    float lod = iblRoughnessOneLevel * roughness;
    return (UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, r, lod + offset));
}

float3 getSpecularDominantDirection(const float3 n, const float3 r, float roughness) {
    return lerp(r, n, roughness * roughness);
}

float3 specularDFG(const PixelParams pixel) {
    /*
#if defined(SHADING_MODEL_CLOTH)
    return pixel.f0 * pixel.dfg.z;
#else
    return lerp(pixel.dfg.xxx, pixel.dfg.yyy, pixel.f0);
#endif
    */
    // Disabled until useable
    return pixel.f0;
}

/**
 * Returns the reflected vector at the current shading point. The reflected vector
 * return by this function might be different from shading.reflected:
 * - For anisotropic material, we bend the reflection vector to simulate
 *   anisotropic indirect lighting
 * - The reflected vector may be modified to point towards the dominant specular
 *   direction to match reference renderings when the roughness increases
 */

float3 getReflectedVector(const PixelParams pixel, const float3 v, const float3 n) {
#if defined(MATERIAL_HAS_ANISOTROPY)
    float3  anisotropyDirection = pixel.anisotropy >= 0.0 ? pixel.anisotropicB : pixel.anisotropicT;
    float3  anisotropicTangent  = cross(anisotropyDirection, v);
    float3  anisotropicNormal   = cross(anisotropicTangent, anisotropyDirection);
    float bendFactor          = abs(pixel.anisotropy) * saturate(5.0 * pixel.perceptualRoughness);
    float3  bentNormal          = normalize(lerp(n, anisotropicNormal, bendFactor));

    float3 r = reflect(-v, bentNormal);
#else
    float3 r = reflect(-v, n);
#endif
    return r;
}

float3 getReflectedVector(const ShadingParams shading, const PixelParams pixel, const float3 n) {
#if defined(MATERIAL_HAS_ANISOTROPY)
    float3 r = getReflectedVector(pixel, shading.view, n);
#else
    float3 r = shading.reflected;
#endif
    return getSpecularDominantDirection(n, r, pixel.roughness);
}

//------------------------------------------------------------------------------
// Prefiltered importance sampling
//------------------------------------------------------------------------------

#if IBL_INTEGRATION == IBL_INTEGRATION_IMPORTANCE_SAMPLING

void isEvaluateClearCoatIBL(const ShadingParams shading, const PixelParams pixel, 
    float specularAO, inout float3 Fd, inout float3 Fr) {
#if defined(MATERIAL_HAS_CLEAR_COAT)
#if defined(MATERIAL_HAS_NORMAL) || defined(MATERIAL_HAS_CLEAR_COAT_NORMAL)
    // We want to use the geometric normal for the clear coat layer
    float clearCoatNoV = clampNoV(dot(shading.clearCoatNormal, shading.view));
    float3 clearCoatNormal = shading.clearCoatNormal;
#else
    float clearCoatNoV = shading.NoV;
    float3 clearCoatNormal = shading.normal;
#endif
    // The clear coat layer assumes an IOR of 1.5 (4% reflectance)
    float Fc = F_Schlick(0.04, 1.0, clearCoatNoV) * pixel.clearCoat;
    float attenuation = 1.0 - Fc;
    Fd *= attenuation;
    Fr *= attenuation;

    PixelParams p;
    p.perceptualRoughness = pixel.clearCoatPerceptualRoughness;
    p.f0 = float3(0.04);
    p.roughness = perceptualRoughnessToRoughness(p.perceptualRoughness);
#if defined(MATERIAL_HAS_ANISOTROPY)
    p.anisotropy = 0.0;
#endif

    float3 clearCoatLobe = isEvaluateSpecularIBL(p, clearCoatNormal, shading.view, clearCoatNoV);
    Fr += clearCoatLobe * (specularAO * pixel.clearCoat);
#endif
}
#endif


//------------------------------------------------------------------------------
// IBL evaluation
//------------------------------------------------------------------------------

void evaluateClothIndirectDiffuseBRDF(const ShadingParams shading, const PixelParams pixel, 
    inout float diffuse) {
#if defined(SHADING_MODEL_CLOTH)
#if defined(MATERIAL_HAS_SUBSURFACE_COLOR)
    // Simulate subsurface scattering with a wrap diffuse term
    diffuse *= Fd_Wrap(shading.NoV, 0.5);
#endif
#endif
}

void evaluateSheenIBL(const ShadingParams shading, const PixelParams pixel, 
    float specularAO, inout float3 Fd, inout float3 Fr) {
#if !defined(SHADING_MODEL_CLOTH) && !defined(SHADING_MODEL_SUBSURFACE)
#if defined(MATERIAL_HAS_SHEEN_COLOR)
    // Albedo scaling of the base layer before we layer sheen on top
    Fd *= pixel.sheenScaling;
    Fr *= pixel.sheenScaling;

    float3 reflectance = pixel.sheenDFG * pixel.sheenColor;
    Fr += reflectance * prefilteredRadiance(shading.reflected, pixel.sheenPerceptualRoughness);
#endif
#endif
}

void evaluateClearCoatIBL(const ShadingParams shading, const PixelParams pixel, 
    float specularAO, inout float3 Fd, inout float3 Fr) {
#if IBL_INTEGRATION == IBL_INTEGRATION_IMPORTANCE_SAMPLING
    isEvaluateClearCoatIBL(pixel, specularAO, Fd, Fr);
    return;
#endif

#if defined(MATERIAL_HAS_CLEAR_COAT)
#if defined(MATERIAL_HAS_NORMAL) || defined(MATERIAL_HAS_CLEAR_COAT_NORMAL)
    // We want to use the geometric normal for the clear coat layer
    float clearCoatNoV = clampNoV(dot(shading.clearCoatNormal, shading.view));
    float3 clearCoatR = reflect(-shading.view, shading.clearCoatNormal);
#else
    float clearCoatNoV = shading.NoV;
    float3 clearCoatR = shading.reflected;
#endif
    // The clear coat layer assumes an IOR of 1.5 (4% reflectance)
    float Fc = F_Schlick(0.04, 1.0, clearCoatNoV) * pixel.clearCoat;
    float attenuation = 1.0 - Fc;
    Fd *= attenuation;
    Fr *= attenuation;
    Fr += prefilteredRadiance(clearCoatR, pixel.clearCoatPerceptualRoughness) * (specularAO * Fc);
#endif
}

void evaluateSubsurfaceIBL(const ShadingParams shading, const PixelParams pixel, 
    const float3 diffuseIrradiance, inout float3 Fd, inout float3 Fr) {
#if defined(SHADING_MODEL_SUBSURFACE)
    float3 viewIndependent = diffuseIrradiance;
    float3 viewDependent = prefilteredRadiance(-shading.view, pixel.roughness, 1.0 + pixel.thickness);
    float attenuation = (1.0 - pixel.thickness) / (2.0 * PI);
    Fd += pixel.subsurfaceColor * (viewIndependent + viewDependent) * attenuation;
#elif defined(SHADING_MODEL_CLOTH) && defined(MATERIAL_HAS_SUBSURFACE_COLOR)
    Fd *= saturate(pixel.subsurfaceColor + shading.NoV);
#endif
}

void combineDiffuseAndSpecular(const PixelParams pixel,
        const float3 n, const float3 E, const float3 Fd, const float3 Fr,
        inout float3 color) {
    const float iblLuminance = 1.0; // Unknown
#if defined(HAS_REFRACTION)
    applyRefraction(pixel, n, E, Fd, Fr, color);
#else
    color.rgb += (Fd + Fr) * iblLuminance;
#endif
}

void evaluateIBL(const ShadingParams shading, const MaterialInputs material, const PixelParams pixel, 
    inout float3 color) {
    float ssao = 1.0; // Not implemented
    float diffuseAO = min(material.ambientOcclusion, ssao);
    float specularAO = computeSpecularAO(shading.NoV, diffuseAO, pixel.roughness);

    // Gather Unity GI data
    UnityGIInput unityData = InitialiseUnityGIInput(shading, pixel);
    // specular layer
    float3 Fr;
#if IBL_INTEGRATION == IBL_INTEGRATION_PREFILTERED_CUBEMAP
    float3 E = specularDFG(pixel);
    float3 r = getReflectedVector(shading, pixel, shading.normal);
    Fr = E * UnityGI_prefilteredRadiance(unityData, r, pixel.perceptualRoughness);
#elif IBL_INTEGRATION == IBL_INTEGRATION_IMPORTANCE_SAMPLING
    // Not supported
    float3 E = float3(0.0); // TODO: fix for importance sampling
    Fr = isEvaluateSpecularIBL(pixel, shading.normal, shading.view, shading.NoV);
#endif
    Fr *= singleBounceAO(specularAO) * pixel.energyCompensation;

    // diffuse layer
    float diffuseBRDF = singleBounceAO(diffuseAO); // Fd_Lambert() is baked in the SH below

    evaluateClothIndirectDiffuseBRDF(shading, pixel, diffuseBRDF);

#if defined(MATERIAL_HAS_BENT_NORMAL)
    float3 diffuseNormal = shading.bentNormal;
#else
    float3 diffuseNormal = shading.normal;
#endif

#if IBL_INTEGRATION == IBL_INTEGRATION_PREFILTERED_CUBEMAP
    float3 diffuseIrradiance = get_diffuseIrradiance(diffuseNormal);
#elif IBL_INTEGRATION == IBL_INTEGRATION_IMPORTANCE_SAMPLING
    float3 diffuseIrradiance = isEvaluateDiffuseIBL(pixel, diffuseNormal, shading.view);
#endif

    float3 Fd = pixel.diffuseColor * diffuseIrradiance * (1.0 - E) * diffuseBRDF;

    // sheen layer
    evaluateSheenIBL(shading, pixel, specularAO, Fd, Fr);

    // clear coat layer
    evaluateClearCoatIBL(shading, pixel, specularAO, Fd, Fr);

    // subsurface layer
    evaluateSubsurfaceIBL(shading, pixel, diffuseIrradiance, Fd, Fr);

    // extra ambient occlusion term
    multiBounceAO(diffuseAO, pixel.diffuseColor, Fd);
    multiBounceSpecularAO(specularAO, pixel.f0, Fr);
    
    // Note: iblLuminance is already premultiplied by the exposure
    combineDiffuseAndSpecular(pixel, shading.normal, E, Fd, Fr, color);
}

#endif // FILAMENT_LIGHT_INDIRECT