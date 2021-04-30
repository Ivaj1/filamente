// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_BRDF_INCLUDED
#define UNITY_STANDARD_BRDF_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityLightingCommon.cginc"

#include "FilamentMaterialInputs.cginc"
#include "FilamentCommonMath.cginc"
#include "FilamentCommonLighting.cginc"
#include "FilamentCommonMaterial.cginc"
#include "FilamentCommonShading.cginc"

#include "FilamentBRDF.cginc"
#include "FilamentShadingStandard.cginc"
#include "FilamentLightIndirect.cginc"
#include "FilamentShadingLit.cginc"
#include "FilamentLightDirectional.cginc"

// Uh... Unity?
#define LambertTerm(x,y) dot(x,y)

//-------------------------------------------------------------------------------------

half4 BRDF1_Unity_PBS (half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness,
    float3 normal, float3 viewDir,
    UnityLight light, UnityIndirect gi)
{

    /*
    float3 h = normalize(shading_view + light.l);

    float NoV = shading_NoV;
    float NoL = saturate(light.NoL);
    float NoH = saturate(dot(shading_normal, h));
    float LoH = saturate(dot(light.l, h));
    */

    float perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

// NdotV should not be negative for visible pixels, but it can happen due to perspective projection and normal mapping
// In this case normal should be modified to become valid (i.e facing camera) and not cause weird artifacts.
// but this operation adds few ALU and users may not want it. Alternative is to simply take the abs of NdotV (less correct but works too).
// Following define allow to control this. Set it to 0 if ALU is critical on your platform.
// This correction is interesting for GGX with SmithJoint visibility function because artifacts are more visible in this case due to highlight edge of rough surface
// Edit: Disable this code by default for now as it is not compatible with two sided lighting used in SpeedTree.
#define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0

#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
    // The amount we shift the normal toward the view vector is defined by the dot product.
    half shiftAmount = dot(normal, viewDir);
    normal = shiftAmount < 0.0f ? normal + viewDir * (-shiftAmount + 1e-5f) : normal;
    // A re-normalization should be applied here but as the shift is small we don't do it to save ALU.
    //normal = normalize(normal);

    float NoV = saturate(dot(normal, viewDir)); // TODO: this saturate should no be necessary here
#else
    half NoV = abs(dot(normal, viewDir));    // This abs allow to limit artifact
#endif

    // Stopgap
    PixelParams pixel = (PixelParams)0;
    pixel.diffuseColor = diffColor;
    pixel.roughness = roughness;
    pixel.f0 = 1.0;
    pixel.energyCompensation = 1.0;

    ShadingParams shading = (ShadingParams)0;
    shading.view = viewDir;
    shading.position = viewDir;
    shading.NoV = NoV;
    shading.normal = normal;
    shading.reflected = -reflect(viewDir, normal);

    float occlusion = 1.0;
    MaterialInputs material = (MaterialInputs)0;
    material.ambientOcclusion = 1.0;

    float3 color = 0.0;//surfaceShading(shading, pixel, fLight, occlusion);
    evaluateIBL(shading, material, pixel, color);
    evaluateDirectionalLight(shading, material, pixel, color);

    #if 0
#   ifdef UNITY_COLORSPACE_GAMMA
        specularTerm = sqrt(max(1e-4h, specularTerm));
#   endif

    // specularTerm * NoL can be NaN on Metal in some cases, use max() to make sure it's a sane value
    specularTerm = max(0, specularTerm * NoL);
#if defined(_SPECULARHIGHLIGHTS_OFF)
    specularTerm = 0.0;
#endif

    // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
    half surfaceReduction;
#   ifdef UNITY_COLORSPACE_GAMMA
        surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
#   else
        surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
#   endif

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(specColor) ? 1.0 : 0.0;

    half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
    half3 color =   diffColor * (gi.diffuse + light.color * diffuseTerm)
                    + specularTerm * light.color * FresnelTerm (specColor, LoH)
                    + surfaceReduction * gi.specular * FresnelLerp (specColor, grazingTerm, NoV);

    return half4(color, 1);
    #endif

    return float4(color, 1.0);
}

half4 BRDF_Filament_Standard (const ShadingParams shading, const MaterialInputs material,
        const PixelParams pixel)
{

    float3 color = 0.0;
    evaluateIBL(shading, material, pixel, color);
    evaluateDirectionalLight(shading, material, pixel, color);

    #if 0
#   ifdef UNITY_COLORSPACE_GAMMA
        specularTerm = sqrt(max(1e-4h, specularTerm));
#   endif

    // specularTerm * NoL can be NaN on Metal in some cases, use max() to make sure it's a sane value
    specularTerm = max(0, specularTerm * NoL);
#if defined(_SPECULARHIGHLIGHTS_OFF)
    specularTerm = 0.0;
#endif

    // surfaceReduction = Int D(NdotH) * NdotH * Id(NdotL>0) dH = 1/(roughness^2+1)
    half surfaceReduction;
#   ifdef UNITY_COLORSPACE_GAMMA
        surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
#   else
        surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
#   endif

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(specColor) ? 1.0 : 0.0;

    half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
    half3 color =   diffColor * (gi.diffuse + light.color * diffuseTerm)
                    + specularTerm * light.color * FresnelTerm (specColor, LoH)
                    + surfaceReduction * gi.specular * FresnelLerp (specColor, grazingTerm, NoV);

    return half4(color, 1);
    #endif

    return float4(color, 1.0);

}

#endif // UNITY_STANDARD_BRDF_INCLUDED
