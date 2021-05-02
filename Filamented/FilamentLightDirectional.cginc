#ifndef FILAMENT_LIGHT_DIRECTIONAL
#define FILAMENT_LIGHT_DIRECTIONAL
//------------------------------------------------------------------------------
// Directional light evaluation
//------------------------------------------------------------------------------

#ifndef FILAMENT_QUALITY
//#define SUN_AS_AREA_LIGHT
#else
#if FILAMENT_QUALITY < FILAMENT_QUALITY_HIGH
#define SUN_AS_AREA_LIGHT
#endif
#endif

float3 sampleSunAreaLight(const float3 lightDirection, const ShadingParams shading) {
    // Replace frameUniforms.sun
    float4 sunParameters = -1;
#if defined(SUN_AS_AREA_LIGHT)
    if (sunParameters.w >= 0.0) {
        // simulate sun as disc area light
        float LoR = dot(lightDirection, shading.reflected);
        float d = sunParameters.x;
        float3 s = shading.reflected - LoR * lightDirection;
        return LoR < d ?
                normalize(lightDirection * d + normalize(s) * sunParameters.y) : shading.reflected;
    }
#endif
    return lightDirection;
}

float4 UnityLightColorIntensitySeperated() {
    return float4(_LightColor0.xyz / _LightColor0.w, _LightColor0.w);

}

Light getDirectionalLight(ShadingParams shading) {
    Light light;
    // note: lightColorIntensity.w is always premultiplied by the exposure
    light.colorIntensity = UnityLightColorIntensitySeperated();
    light.l = sampleSunAreaLight(_WorldSpaceLightPos0.xyz, shading);
    light.attenuation = 1.0;
    light.NoL = saturate(dot(shading.normal, light.l));
    return light;
}

// Much of this function has changed from the original because we still use 
// Unity's BIRP shadow handling. Sorry!
void evaluateDirectionalLight(const ShadingParams shading, const MaterialInputs material,
        const PixelParams pixel, inout float3 color) {

    Light light = getDirectionalLight(shading);

    float visibility = 1.0;
#if defined(HAS_SHADOWING)
    if (light.NoL > 0.0) {
        float ssContactShadowOcclusion = 0.0;

        // hasDirectionalShadows && cascadeHasVisibleShadows
        if (0) {
            // apply directional shadows to visibility here
        }
        // if contact shadows are enabled
        if (true && visibility > 0.0) {
            // ssContactShadowOcclusion = screenSpaceContactShadow(light.l);
        }

        visibility *= 1.0 - ssContactShadowOcclusion;

        #if defined(MATERIAL_HAS_AMBIENT_OCCLUSION)
        visibility *= computeMicroShadowing(light.NoL, material.ambientOcclusion);
        #endif
    } else {
#if defined(MATERIAL_CAN_SKIP_LIGHTING)
        return;
#endif
    }
#elif defined(MATERIAL_CAN_SKIP_LIGHTING)
    if (light.NoL <= 0.0) return;
#endif

    color.rgb += surfaceShading(shading, pixel, light, visibility);
}

#endif // FILAMENT_LIGHT_DIRECTIONAL