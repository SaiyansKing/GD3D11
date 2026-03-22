//--------------------------------------------------------------------------------------
// World/VOB-Pixelshader for G2D3D11 by Degenerated
//--------------------------------------------------------------------------------------
#include <DS_Defines.h>

#include <AtmosphericScattering.h>

cbuffer DS_ScreenQuadConstantBuffer : register( b0 )
{
	matrix SQ_InvProj; // Optimize out!
	matrix SQ_InvView;
	matrix SQ_View;
	
	matrix SQ_RainViewProj;
	
	float3 SQ_LightDirectionVS;
	float SQ_ShadowmapSize;
	
	float4 SQ_LightColor;
	matrix SQ_ShadowView;
	matrix SQ_ShadowProj;
	
	matrix SQ_RainView;
	matrix SQ_RainProj;
	
	float SQ_ShadowStrength;
	float SQ_ShadowAOStrength;
	float SQ_WorldAOStrength;
	float SQ_Pad;
};

//--------------------------------------------------------------------------------------
// Textures and Samplers
//--------------------------------------------------------------------------------------
SamplerState SS_Linear : register( s0 );
SamplerState SS_samMirror : register( s1 );
SamplerComparisonState SS_Comp : register( s2 );
Texture2D	TX_Diffuse : register( t0 );
Texture2D	TX_Nrm : register( t1 );
Texture2D	TX_Depth : register( t2 );
Texture2D	TX_Shadowmap : register( t3 );
Texture2D	TX_RainShadowmap : register( t4 );
TextureCube	TX_ReflectionCube : register( t5 );
Texture2D	TX_Distortion : register( t6 );
Texture2D	TX_SI_SP : register( t7 );

//--------------------------------------------------------------------------------------
// Input / Output structures
//--------------------------------------------------------------------------------------
struct PS_INPUT
{
	float2 vTexCoord 		: TEXCOORD0;
	float3 vEyeRay			: TEXCOORD1;
	float4 vPosition		: SV_POSITION;
};

float3 VSPositionFromDepth(float depth, float2 vTexCoord)
{
	// Get NDC clip-space position
	float4 vProjectedPos = float4(vTexCoord * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f), depth, 1.0f);

	// Transform by the inverse projection matrix
	float4 vPositionVS = mul(vProjectedPos, SQ_InvProj); //invViewProj == invProjection here

	// Divide by w to get the view-space position
	return vPositionVS.xyz / vPositionVS.www;
}

//--------------------------------------------------------------------------------------
// Blinn-Phong Lighting Reflection Model
//--------------------------------------------------------------------------------------
float CalcBlinnPhongLighting(float3 N, float3 H)
{
    return saturate(dot(N, H));
}

float2 TexOffset( int u, int v )
{
    return float2( u * 1.0f/SQ_ShadowmapSize, v * 1.0f/SQ_ShadowmapSize );
}

float IsInShadow(float3 wsPosition, Texture2D shadowmap, SamplerComparisonState samplerState)
{
	float4 vShadowSamplingPos = mul(float4(wsPosition, 1), mul(SQ_ShadowView, SQ_ShadowProj));
	vShadowSamplingPos.xyz /= vShadowSamplingPos.www;
	
	float2 projectedTexCoords = vShadowSamplingPos.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
	return shadowmap.SampleCmpLevelZero(samplerState, projectedTexCoords.xy, vShadowSamplingPos.z);
}

float IsWet(float3 wsPosition, Texture2D shadowmap, SamplerComparisonState samplerState, matrix viewProj)
{
	float4 vShadowSamplingPos = mul(float4(wsPosition, 1), mul(SQ_RainView, SQ_RainProj));
	vShadowSamplingPos.xyz /= vShadowSamplingPos.www;
	
	float2 projectedTexCoords = vShadowSamplingPos.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);
	float bias = 0.001f;
	return shadowmap.SampleCmpLevelZero( samplerState, projectedTexCoords.xy, vShadowSamplingPos.z - bias);
}

float ComputeShadowValue(float2 uv, float3 wsPosition, Texture2D shadowmap, SamplerComparisonState samplerState, float distance, float vertLighting, matrix viewProj, float bias = 0.01f, float softnessScale = 1.0f)
{
	// Reconstruct VS World ShadowViewPosition from depth
	float4 vShadowSamplingPos = mul(float4(wsPosition, 1), viewProj);
	vShadowSamplingPos.xyz /= vShadowSamplingPos.www;
	
	float2 projectedTexCoords = vShadowSamplingPos.xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);	
	float shadow = 1.0f;
	if( !(projectedTexCoords.x > 1 || projectedTexCoords.y > 1 ||
		projectedTexCoords.x < 0 || projectedTexCoords.y < 0))
	{
#if SHD_FILTER_16TAP_PCF
		//return shadowmap.SampleCmpLevelZero( samplerState, projectedTexCoords.xy, vShadowSamplingPos.z - 0.00001f);
		//return shadowmap.Sample(SS_Linear, projectedTexCoords).r > vShadowSamplingPos.z ? 1 : 0;
		
		float dist = shadowmap.Sample(SS_Linear, projectedTexCoords).r - vShadowSamplingPos.z;
		
		//return dist * 10.0f;
		
		//PCF sampling for shadow map
		float sum = 0;
		float x, y;
		
		float dx = ddx(projectedTexCoords.xy);
		float dy = ddy(projectedTexCoords.xy);
	 
		float minValue = 999999.0f;
		/*for (y = -1.5; y <= 1.5; y += 1.0)
		{
			for (x = -1.5; x <= 1.5; x += 1.0)
			{
				
				minValue = min(minValue, shadowmap.SampleGrad(SS_Linear, projectedTexCoords.xy + TexOffset(x,y), dx, dy)).r;
			}
		}*/
		
		float scale = softnessScale;//1 + (minValue - vShadowSamplingPos.z) * 500.0f;
		
	 
		//perform PCF filtering on a 4 x 4 texel neighborhood
		[unroll] for (y = -1.5; y <= 1.5; y += 1.0)
		{
			[unroll] for (x = -1.5; x <= 1.5; x += 1.0)
			{
				sum += shadowmap.SampleCmpLevelZero( samplerState, projectedTexCoords.xy + TexOffset(x,y) * scale, vShadowSamplingPos.z - bias);
			}
		}
	 
		float shadowFactor = sum / 16.0;
	
		shadow *= shadowFactor;
#else
		shadow = shadowmap.SampleCmpLevelZero( samplerState, projectedTexCoords.xy, vShadowSamplingPos.z - bias);
#endif
	}
	
	float border;
	border = pow(abs(projectedTexCoords.x), 16.0f);
	border += pow(abs(projectedTexCoords.y), 16.0f);
	border += pow(abs(1.0f-projectedTexCoords.x), 16.0f);
	border += pow(abs(1.0f-projectedTexCoords.y), 16.0f);
	shadow = lerp(shadow, vertLighting, saturate(border));
	
	return saturate(shadow);
}

static const float WEIGHT_BIAS = -0.55;
static const float WEIGHT_MUL = 0.7;

/** Applys normal-deformation for the rain */
void ApplyRainNormalDeformation(inout float3 vsNormal, float3 wsPosition, inout float3 diffuse, out float3 wsNormal)
{
	// Need worldspace normal for this
	wsNormal = mul(vsNormal, (float3x3)SQ_InvView).xyz;
	
	float2 groundDir = normalize(float2(0.1f, 0.1f) + saturate(cross(wsNormal, float3(0.0f,1.0f,0.0f)).xz));
	
	const float scale = 1000.0f;
	float2 uv[4] = {wsPosition.zy / scale, 
					wsPosition.xz / (scale*2),
					wsPosition.xz / (scale*2),					
					wsPosition.xy / scale};
	
	float groundSpeed = 0.1f * AC_RainFXWeight;
	float downSpeed = 0.2f * AC_RainFXWeight;
	uv[0] += float2(0, AC_Time * downSpeed);
	uv[1] += float2(AC_Time * groundSpeed, AC_Time * groundSpeed);
	uv[2] = uv[2] * float2(0.8f, 1.2f) + float2(-AC_Time * groundSpeed * 0.7f, AC_Time * groundSpeed * 0.4f);
	uv[3] += float2(0, AC_Time * downSpeed);
	
	// Create weights for all 3 axis
	float3 weights = float3(abs(wsNormal.x),
							abs(wsNormal.y),
							abs(wsNormal.z));
							
	// Tighten up the blending zone:
	weights = (weights + WEIGHT_BIAS) * WEIGHT_MUL;
	weights = max(weights, 0);						
							
	weights /= (weights.x + weights.y +
				weights.z ).xxx;
				
	weights.xz *= 0.6f;
	weights.y *= 0.7f;
		
	float3 dist[3] =  {normalize((TX_Distortion.Sample(SS_Linear, uv[0]).zyx * 2 - 1)), 
					  normalize((TX_Distortion.Sample(SS_Linear, uv[1]).xzy * 2 - 1)) * 0.5f + 
					  normalize((TX_Distortion.Sample(SS_Linear, uv[2]).xzy * 2 - 1)) * 0.5f, 
					  normalize((TX_Distortion.Sample(SS_Linear, uv[3]).xyz * 2 - 1))};
		
	weights = pow(weights, 4.0f);
		
	const float distWeight = 0.9f;
	
	// Sample the distortion-texture for all 3 axis
	for(int i=0;i<3;i++)
	{		
		// Add to normal
		wsNormal = lerp(wsNormal, dist[i], weights[i] * distWeight);//distWeight * weights[i]); 
	}

	wsNormal = normalize(wsNormal);
	//diffuse.xyz = wsNormal;
	
	vsNormal = normalize(mul(wsNormal, (float3x3)SQ_View).xyz);
}

/** Returns new diffusecolor (rgb)*/
void ApplySceneWettness(float3 wsPosition, float3 vsPosition, float3 vsDir, inout float3 vsNormal, in out float3 diffuse, in out float specIntensity, in out float specPower, out float specAdd)
{
	// Ask the rain-shadowmap if we can hit this pixel
	float pixelWettnes = ComputeShadowValue(0.0f, wsPosition, TX_RainShadowmap, SS_Comp, vsPosition.z, 1.0f, mul(SQ_RainView, SQ_RainProj), 0.0001f, 2.5f) * AC_SceneWettness;
	pixelWettnes = pixelWettnes < 0.001f ? 0 : pixelWettnes;
	
	//IsWet(wsPosition, TX_RainShadowmap, SS_Comp) * AC_SceneWettness;

	float3 vsNormalCpy = vsNormal;
	
	// Apply water-effects
	float3 nrm = vsNormal;
	float3 wsNormal;
	ApplyRainNormalDeformation(nrm, wsPosition, diffuse.rgb, wsNormal);
	pixelWettnes *= 1 - pow(saturate(dot(wsNormal, float3(0,-1,0))), 4.0f);
	
	// Apply quality multiplier: Simple = disabled, Advanced = full
	if (AC_RainEffectsQuality == 1) // RAIN_QUALITY_SIMPLE
	{
		pixelWettnes = 0; // Completely disable wet surface effects for Simple mode
	}
	
	vsNormal = lerp(vsNormal, nrm, AC_RainFXWeight * pixelWettnes * 0.5f); // Only apply deformation if it's actually raining
	
	// Get fresnel-effect
	float fresnel = pow(1.0f - max(0.0f, dot(vsNormal, -vsDir)), 160.0f);
	
	
	//vsNormalCpy.z *= 0.3f;
	//vsNormalCpy = normalize(vsNormalCpy);
	
	// Scale specular intensity and power
	specIntensity = lerp(specIntensity, 0.0, pixelWettnes);
	specPower = lerp(specPower, 150.0f, pixelWettnes);
	
	// Reflection
	float3 reflect_vec = reflect(-vsDir.xyz, vsNormal.xyz);
	
	// sample reflection cube
	float4 refCube = TX_ReflectionCube.Sample(SS_Linear, reflect_vec);
	float3 reflection = refCube.rgb * refCube.a;
	
	float3 l1 = normalize(float3(0.0f,0.5f,-1.0f));
	float3 l2 = normalize(mul(normalize(float3(-0.333f,0.533f,0.333f)), (float3x3)SQ_View));
	float3 l3 = normalize(mul(normalize(float3(0,0.566f,-0.666f)), (float3x3)SQ_View));
	
	float3 H_1 = normalize(l1 + vsDir);
	float3 H_2 = normalize(l2 + vsDir);
	float3 H_3 = normalize(l3 + vsDir);
	float spec1 = CalcBlinnPhongLighting(vsNormal, H_1);
	float spec2 = CalcBlinnPhongLighting(vsNormal, H_2);
	float spec3 = CalcBlinnPhongLighting(vsNormal, H_3);
		
	// power the reflection 
	reflection = pow(reflection, 2.5f) * 1.0f;
	//reflection += fresnel * 0.1f;
	
	reflection += pow(spec1, specPower) * 0.7f + pow(spec2, specPower) * 0.7f + pow(spec3, specPower) * 0.6f;
	
	// Compute wet pixel color
	float diffuseLum = dot(diffuse, float3(0.3333f,0.3333f,0.3333f));
	float3 wetPixel = lerp(diffuseLum, diffuse, 0.75f) * 0.75f; // Desaturate and darken the scene a bit	
	
	
	
	// Scale the total amount of spec-lighting by the wetness factor and whether the scene is currently drying out or it's still raining
	specAdd = reflection * pixelWettnes * lerp(0.08f, 0.10f, AC_RainFXWeight);
	diffuse = lerp(diffuse, wetPixel, pixelWettnes);
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PSMain( PS_INPUT Input ) : SV_TARGET
{
	// Get screen UV
	float2 uv = Input.vTexCoord; 
	
	// Look up the diffuse color
    float4 diffuse = TX_Diffuse.Sample(SS_Linear, uv);
	float vertLighting = diffuse.a;
	
	// Get the second GBuffer
	float4 gb2 = TX_Nrm.Sample(SS_Linear, uv);
	
	// If we dont have a normal, just return the diffuse color
	if(gb2.w < 0.001f)
		return float4(diffuse.rgb, 1);
	
	// Decode the view-space normal back
    float3 normal = normalize(gb2.xyz);
	
	// Get specular parameters
	float4 gb3 = TX_SI_SP.Sample(SS_Linear, uv);
	float specIntensity = gb3.x;
	float specPower = gb3.y;
	
	// Reconstruct VS World Position from depth
	float expDepth = TX_Depth.Sample(SS_Linear, uv).r;
	float3 vsPosition = VSPositionFromDepth(expDepth, uv);
	float3 wsPosition = mul(float4(vsPosition, 1), SQ_InvView).xyz;
	float3 V = normalize(-vsPosition);
	
#if SHD_ENABLE
	//return float4(mul(float4(wsPosition, 1), mul(SQ_ShadowView, SQ_ShadowProj)).xyz, 1);
	
	// Get shadowing
	float shadow = 0.0f;
	if(AC_LightPos.y > 0) // only get shadow value if it isn't night-time otherwise report that the whole scene is in shadow
		shadow = ComputeShadowValue(uv, wsPosition, TX_Shadowmap, SS_Comp, vsPosition.z, vertLighting, mul(SQ_ShadowView, SQ_ShadowProj), lerp(0.00005f, 0.0001f, vsPosition.z / 1000));
#else
	float shadow = vertLighting;
#endif
	//shadow = 1.0f;

	// Sunrays
	/*float3 vsDir = normalize(vsPosition);
	const int numSamples = 100;
	float stepSize = 1000.0f / numSamples;
	float shaft = 0.0f;
	for(float r=0;r < 1000.0f;r+=stepSize)
	{
		float3 vsRayPos = vsDir * r;
		float3 wsRayPos = mul(float4(vsRayPos, 1), SQ_InvView).xyz;
		
		float s = IsInShadow(wsRayPos, TX_Shadowmap, SS_Comp);
		
		shaft += s / numSamples;
	}*/
	
	
	
	// Compute wettness
	float specWet = 0.0f;
	
#ifdef APPLY_RAIN_EFFECTS
	ApplySceneWettness(wsPosition, vsPosition, V, normal, diffuse.rgb, specIntensity, specPower, specWet);
	
	// Boost specWet when not in shadow
	specWet += specWet * shadow;
#endif
	// Compute specular lighting
	
	float3 H = normalize(SQ_LightDirectionVS + V);
	float spec = CalcBlinnPhongLighting(normal, H);
	float specMod = pow(dot(float3(0.333f,0.333f,0.333f), diffuse.rgb), 2);
	
	
	
	//return float4(diffuse.rgb, 1);
	
	float4 lightColor = SQ_LightColor;
    lightColor.rgb = lerp(lightColor.rgb, lightColor.rgb * 0.8f, AC_SceneWettness);
	
	// Apply sunlight
	float sunStrength = dot(lightColor.rgb, float3(0.333f,0.333f,0.333f));
	
	float vertAO = lerp(pow(saturate(vertLighting * 2), 2), 1.0f, 0.5f);
	float sun = saturate(dot(normalize(SQ_LightDirectionVS), normal) * shadow) * 1.0f;

	spec = pow(spec, specPower) * specIntensity;
	float3 specBare = spec * lightColor.rgb * sun + specWet * lightColor.rgb;
	float3 specColored = saturate(lerp(specBare, specBare * diffuse.rgb, specMod));
	
	float shadowAO = lerp(1.0f, vertLighting, SQ_ShadowAOStrength);
	float worldAO = lerp(1.0f, vertLighting, SQ_WorldAOStrength);
	
	float3 litPixel = lerp( diffuse.rgb * SQ_ShadowStrength * sunStrength * shadowAO, 
							diffuse.rgb * lightColor.rgb * lightColor.a * worldAO, sun) 
				  + specColored;
	
    float fresnel = pow(1.0f - saturate(dot(normal, V)), 10.0f);
    litPixel += lerp(fresnel * litPixel * 0.5f, 0.0f, sun);
	
	// Run scattering
	litPixel = ApplyAtmosphericScatteringGround(wsPosition, litPixel.rgb);
	
	
	// Fix indoor stuff
	//litPixel = lerp(diffuse * vertLighting, litPixel, vertLighting < 0.9f ? 0 : 1);
	//diffuse.rgb = lerp(diffuse.rgb, 1.0f, clamp(shaft, 0.0f, 0.4f));
	
	
	//return float4(sun.rgb, 1);
	//return float4(vertLighting.rrr, 1);
	return float4(litPixel.rgb, 1);
	//return float4(pow(spec, specPower) * specIntensity.xxx * diffuse.rgb * SQ_LightColor.rgb,1);
	
}

