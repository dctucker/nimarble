#version 330 core

in vec3 UV;
in vec4 fragmentColor;
in vec3 Position_worldspace;
in vec3 Normal_cameraspace;
in vec3 EyeDirection_cameraspace;
in vec3 LightDirection_cameraspace;

out vec4 color;

// uniform mat4 MV;
uniform vec3  LightPosition_worldspace;
uniform float LightPower;
uniform vec3  LightColor;
uniform float AmbientWeight;
uniform vec3  SpecularColor;
uniform sampler2DArray myTextureSampler;

void main(){
	vec4 textureColor = texture( myTextureSampler, UV );
	// Material properties
	vec3 MaterialDiffuseColor = mix(fragmentColor.rgb, textureColor.rgb, 0.2);
	//vec3 MaterialDiffuseColor = texture( myTextureSampler, UV ).rgb;
	vec3 MaterialAmbientColor = AmbientWeight * MaterialDiffuseColor;
	vec3 MaterialSpecularColor = SpecularColor;

	// Distance to the light
	float distance = length( LightPosition_worldspace - Position_worldspace );

	// Normal of the computed fragment, in camera space
	vec3 n = normalize( Normal_cameraspace );
	// Direction of the light (from the fragment to the light)
	vec3 l = normalize( LightDirection_cameraspace );
	// Cosine of the angle between the normal and the light direction, 
	// clamped above 0
	//  - light is at the vertical of the triangle -> 1
	//  - light is perpendicular to the triangle -> 0
	//  - light is behind the triangle -> 0
	float cosTheta = clamp( dot( n,l ), 0,1 );
	
	// Eye vector (towards the camera)
	vec3 E = normalize(EyeDirection_cameraspace);
	// Direction in which the triangle reflects the light
	vec3 R = reflect(-l,n);
	// Cosine of the angle between the Eye vector and the Reflect vector,
	// clamped to 0
	//  - Looking into the reflection -> 1
	//  - Looking elsewhere -> < 1
	float cosAlpha = clamp( dot( E,R ), 0,1 );
	
	float distance2i = 1.0 / (distance * distance);
	// Ambient : simulates indirect lighting
	// Diffuse : "color" of the object
	// Specular : reflective highlight, like a mirror
	color = vec4(
		MaterialAmbientColor  +
		MaterialDiffuseColor  * LightColor * LightPower *        cosTheta * distance2i +
		MaterialSpecularColor * LightColor * LightPower * pow(cosAlpha,5) * distance2i
		, fragmentColor.a);
}

