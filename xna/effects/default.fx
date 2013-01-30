


uniform extern int textureCount = 0;

texture texture0: register(t0);
texture texture1: register(t1);
texture texture2: register(t2);
texture texture3: register(t3);

sampler textureSampler[4]: register(s0);

struct CTextureStageStage
{
	float2 scale;
	float2 offset;
	int blend;
	int coords;
	float2 angle;
};

CTextureStageStage textureStages[8];

//-----------------------------------------------------------------------------
// Fog settings
//-----------------------------------------------------------------------------

uniform extern float fogNear;
uniform extern float fogFar;
uniform extern float3 fogColor;


//-----------------------------------------------------------------------------
// Material settings
//-----------------------------------------------------------------------------

uniform extern float4 diffuseColor;
uniform extern float4 ambientColor;
uniform extern float  shininess;


//-----------------------------------------------------------------------------
// Lights
// All directions and positions are in world space and must be unit vectors
//-----------------------------------------------------------------------------


struct CLight
{
	float3 	vPos;				
	float 	fRange;
	float3 	vDir;
	float 	InnerAngle;
	float3 	vDiffuse;
	float 	OuterAngle;
	int 	iType;
	float3  pad;
};

//initial and range of directional, point and spot lights within the light array
uniform extern int iLightDirIni;
uniform extern int iLightDirNum;
uniform extern int iLightPointIni;
uniform extern int iLightPointNum;
uniform extern int iLightSpotIni;
uniform extern int iLightSpotNum;

CLight lights[4];

struct COLOR_PAIR
{
   float3 Color;
   float3 ColorSpec;
};


//-----------------------------------------------------------------------------
// Matrices
//-----------------------------------------------------------------------------

uniform extern float4x4 world;		
uniform extern float4x4 view;		
uniform extern float4x4 projection;	
uniform const float3	eyePosition;

//-----------------------------------------------------------------------------
// Structure definitions
//-----------------------------------------------------------------------------

struct VertexShaderInput 
{
	 float4 Position					:	POSITION;
     float4 Color						:	COLOR0;
	 float3 Normal						:	NORMAL;
     float2 TextureCoordinate0			:	TEXCOORD0;
	 float2 TextureCoordinate1			:	TEXCOORD1;
};

struct VertexShaderOutput 
{
	 float4 Position					:	POSITION;
     float4 Color						:	COLOR0;
	 float3 Normal						:	NORMAL;
	 float2 TextureCoordinate0			:	TEXCOORD0;
	 float2 TextureCoordinate1			:	TEXCOORD1;
	 float4 WorldPosition				: 	TEXCOORD2;
	 float4x4 LightDir					:   TEXCOORD3;
	 float  Fog 						:	TEXCOORD7;
};


struct PixelShaderOutput
{
    float4 Color 						: 	COLOR0;
};

//-----------------------------------------------------------------------------
// Compute point light
//-----------------------------------------------------------------------------


COLOR_PAIR DoPointLight(float3 lightDir, float3 E, float3 N, float att)
{
	COLOR_PAIR r = (COLOR_PAIR)0;
	float3 L = normalize(lightDir);

	float lambertTerm = clamp(dot(N,L),0.f,1.f);
	if(lambertTerm > 0.0) 
	{
		r.Color = lambertTerm* (att);
		r.ColorSpec = shininess * pow(saturate(dot(reflect(-L, N),E)),  80.0f)* att;
	}
	return r;
}

//-----------------------------------------------------------------------------
// Compute spot light
//-----------------------------------------------------------------------------

COLOR_PAIR DoSpotLight(float3 lightDir,float3 E, float3 N, float3 dir, float att, float theta, float pi)
{
	COLOR_PAIR r = (COLOR_PAIR)0;
	float3 L = normalize(lightDir);
	
	float lambertTerm = clamp(dot(N,L),0.f,1.f);
	if(lambertTerm > 0.0)
	{
		float angle = acos(dot(-normalize(lightDir.xyz),normalize(dir)));
		float f = smoothstep(theta, pi,angle );
		r.Color = lambertTerm * att *f;
		r.ColorSpec =  shininess * pow(saturate(dot(reflect(-L, N),E)),  80.0f)* att*f;
	}
	return r;
}

//-----------------------------------------------------------------------------
// Compute directional light
//-----------------------------------------------------------------------------

COLOR_PAIR DoDirLight(float3 lightDir,float3 E, float3 N)
{
	COLOR_PAIR r = (COLOR_PAIR)0;
	float3 L = normalize(-lightDir);
	float lambertTerm =  clamp(dot(N,L),0.f,1.f);
	r.Color = lambertTerm;
	r.ColorSpec = 10*shininess * pow(saturate(dot(reflect(-L,N),E)),  80.0f);
	return r;
}

//-----------------------------------------------------------------------------
// Pixel shader
//-----------------------------------------------------------------------------

float4 PixelShaderX(VertexShaderOutput input,
							uniform int vertexcolor,
							uniform int textures,
							uniform int lighting,
							uniform int fog, 
							uniform int coords) : COLOR
{
	 int i =0;
	 
	 float4 color;
	 if( vertexcolor )
	 {
	 	color = input.Color;
  	 }
	 else
	 {
	 	color = diffuseColor;
	 }

	 if( textures )
	 {
 		[unroll]
	    for( i = 0; i< textureCount; ++i) 
		{
			// get coords for selected index
			float2 ccc = (1-textureStages[i].coords)*input.TextureCoordinate0 + 
						 (textureStages[i].coords)*input.TextureCoordinate1;
			
			// transform
			ccc *= textureStages[i].scale + textureStages[i].offset;

			// multiply with base color
			color *= tex2D(textureSampler[i],ccc);
		}
	 }
	  
	 if( lighting ) 
	 {
	 	float3 shading = ambientColor;
	 	float3 specular = 0;
	 	int index;
	 	COLOR_PAIR p;
		
	 	float3 N = normalize(input.Normal);
		float3 E = normalize(eyePosition - input.WorldPosition.xyz);

		for( i = 0; i< iLightDirNum; ++i)
		{
			index = iLightDirIni+i;
			p = DoDirLight(lights[index].vDir,E,N);
			shading += p.Color * lights[index].vDiffuse;
			specular += p.ColorSpec;
		}

		for( i = 0; i< iLightPointNum; ++i) 
		{
			index = iLightPointIni+i;
			p =  DoPointLight(input.LightDir[index].xyz,E,N,input.LightDir[index].w);
			shading += p.Color * lights[index].vDiffuse;
			specular += p.ColorSpec;
		}
	 
	 
	 	for( i = 0; i< iLightSpotNum; ++i)
		{
			index = iLightSpotIni+i;
	  		p =  DoSpotLight(
								input.LightDir[index].xyz, E,N, 
								lights[index].vDir, 
								input.LightDir[index].w, 
								lights[1].InnerAngle,lights[1].OuterAngle);
								
	 		shading += p.Color * lights[index].vDiffuse;
			specular += p.ColorSpec;
		}
		
		color.rgb *= saturate(shading);
		color.rgb += specular;
	 }

	 if( fog )
	 {
	 	color.rgb  = lerp(color.rgb ,fogColor, input.WorldPosition.z);
	 }
	 
	 return color;
}

//-----------------------------------------------------------------------------
// Vertex shader
//-----------------------------------------------------------------------------

VertexShaderOutput VertexShaderX(VertexShaderInput input,
							uniform int vertexcolor,
							uniform int textures,
							uniform int lighting,
							uniform int fog) 
										
{

	VertexShaderOutput output = (VertexShaderOutput)0;
	float4 worldPosition = mul(input.Position, (world));
	float4 viewPosition = mul(worldPosition, (view));
	output.Position=mul( viewPosition, (projection));
	output.Color = input.Color;
	 
	 
	 if(textures)
	 {
	 	output.TextureCoordinate0 = input.TextureCoordinate0;
	 	output.TextureCoordinate1	= input.TextureCoordinate1;
	 }
	 
	 if( lighting )
	 {
		output.Normal =  mul(input.Normal,(float3x3)world);
		output.WorldPosition = worldPosition;
		for( int i = 0; i< 4; ++i )
		{
			 output.LightDir[i].xyz = lights[i].vPos.xyz - worldPosition.xyz;
			 output.LightDir[i].w = 1.0f/(lights[i].fRange*length(output.LightDir[i]));	
		}
	 }
	 
	 if(fog)
	 {
	 	 output.WorldPosition.z  = saturate((length(eyePosition-worldPosition) - fogNear)/(fogFar - fogNear)); 
	 }
	 else
	 {
	 	output.WorldPosition.z = 1;
	 }
	
	 return output;
}

//-----------------------------------------------------------------------------
// Shader and technique definitions
//-----------------------------------------------------------------------------


VertexShader VSArray[16] =
{
	 compile vs_3_0 VertexShaderX(0,0,0,0),
	 compile vs_3_0 VertexShaderX(0,0,0,1),
	 compile vs_3_0 VertexShaderX(0,0,1,0),
	 compile vs_3_0 VertexShaderX(0,0,1,1),
	 compile vs_3_0 VertexShaderX(0,1,0,0),
	 compile vs_3_0 VertexShaderX(0,1,1,1),
	 compile vs_3_0 VertexShaderX(0,1,1,0),
	 compile vs_3_0 VertexShaderX(0,1,1,1),
	 compile vs_3_0 VertexShaderX(1,0,0,0),
	 compile vs_3_0 VertexShaderX(1,0,0,1),
	 compile vs_3_0 VertexShaderX(1,0,1,0),
	 compile vs_3_0 VertexShaderX(1,0,1,1),
	 compile vs_3_0 VertexShaderX(1,1,0,0),
	 compile vs_3_0 VertexShaderX(1,1,0,1),
	 compile vs_3_0 VertexShaderX(1,1,1,0),
	 compile vs_3_0 VertexShaderX(1,1,1,1)
};

PixelShader PSArray[16] =
{
	 compile ps_3_0 PixelShaderX(0,0,0,0,1),
	 compile ps_3_0 PixelShaderX(0,0,0,1,1),
	 compile ps_3_0 PixelShaderX(0,0,1,0,1),
	 compile ps_3_0 PixelShaderX(0,0,1,1,1),
	 compile ps_3_0 PixelShaderX(0,1,0,0,1),
	 compile ps_3_0 PixelShaderX(0,1,0,1,1),
	 compile ps_3_0 PixelShaderX(0,1,1,0,1),
	 compile ps_3_0 PixelShaderX(0,1,1,1,1),
	 compile ps_3_0 PixelShaderX(1,0,0,0,1),
	 compile ps_3_0 PixelShaderX(1,0,0,1,1),
	 compile ps_3_0 PixelShaderX(1,0,1,0,1),
	 compile ps_3_0 PixelShaderX(1,0,1,1,1),
	 compile ps_3_0 PixelShaderX(1,1,0,0,1),
	 compile ps_3_0 PixelShaderX(1,1,0,1,1),
	 compile ps_3_0 PixelShaderX(1,1,1,0,1),
	 compile ps_3_0 PixelShaderX(1,1,1,1,1),
};


int shaderIndex = 0;

technique t1 { 
	pass P0 {
	    VertexShader = VSArray[shaderIndex]; 
	    PixelShader = PSArray[shaderIndex];
	}
}

