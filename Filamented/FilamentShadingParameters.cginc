//------------------------------------------------------------------------------
// Material evaluation
//------------------------------------------------------------------------------

/**
 * Computes global shading parameters used to apply lighting, such as the view
 * vector in world space, the tangent frame at the shading point, etc.
 */
 /*
void computeShadingParams() {
#if defined(HAS_ATTRIBUTE_TANGENTS)
    float3 n = vertex_worldNormal;
#if defined(MATERIAL_NEEDS_TBN)
    float3 t = vertex_worldTangent.xyz;
    float3 b = cross(n, t) * sign(vertex_worldTangent.w);
#endif

#if defined(MATERIAL_HAS_DOUBLE_SIDED_CAPABILITY)
    if (isDoubleSided()) {
        n = gl_FrontFacing ? n : -n;
#if defined(MATERIAL_NEEDS_TBN)
        t = gl_FrontFacing ? t : -t;
        b = gl_FrontFacing ? b : -b;
#endif
    }
#endif

    shading_geometricNormal = normalize(n);

#if defined(MATERIAL_NEEDS_TBN)
    // We use unnormalized post-interpolation values, assuming mikktspace tangents
    shading_tangentToWorld = mat3(t, b, n);
#endif
#endif

    shading_position = vertex_worldPosition;
    shading_view = normalize(frameUniforms.cameraPosition - shading_position);

    // we do this so we avoid doing (matrix multiply), but we burn 4 varyings:
    //    p = clipFromWorldMatrix * shading_position;
    //    shading_normalizedViewportCoord = p.xy * 0.5 / p.w + 0.5
    shading_normalizedViewportCoord = vertex_position.xy * (0.5 / vertex_position.w) + 0.5;
}
*/

/**
 * Computes global shading parameters that the material might need to access
 * before lighting: N dot V, the reflected vector and the shading normal (before
 * applying the normal map). These parameters can be useful to material authors
 * to compute other material properties.
 *
 * This function must be invoked by the user's material code (guaranteed by
 * the material compiler) after setting a value for MaterialInputs.normal.
 */
void prepareMaterial(inout ShadingParams shading, const MaterialInputs material) {
#if defined(HAS_ATTRIBUTE_TANGENTS)
#if defined(MATERIAL_HAS_NORMAL)
    shading.normal = normalize(mul(shading.tangentToWorld, material.normal));
#else
    shading.normal = shading.geometricNormal;
#endif // MATERIAL_HAS_NORMAL
    shading.NoV = clampNoV(dot(shading.normal, shading.view));
    shading.reflected = reflect(-shading.view, shading.normal);

#if defined(MATERIAL_HAS_BENT_NORMAL)
    shading.bentNormal = normalize(mul(shading.tangentToWorld, material.bentNormal));
#endif // MATERIAL_HAS_BENT_NORMAL

#if defined(MATERIAL_HAS_CLEAR_COAT)
#if defined(MATERIAL_HAS_CLEAR_COAT_NORMAL)
    shading.clearCoatNormal = normalize(mul(shading.tangentToWorld, material.clearCoatNormal));
#else
    shading.clearCoatNormal = shading.geometricNormal;
#endif // MATERIAL_HAS_CLEAR_COAT_NORMAL
#endif // MATERIAL_HAS_CLEAR_COAT
#endif // HAS_ATTRIBUTE_TANGENTS
}
