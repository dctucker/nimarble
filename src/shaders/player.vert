#version 330 core

layout (location = 0) in vec3 vertexPosition_modelspace;
layout (location = 1) in vec4 vertexColor;
layout (location = 2) in vec3 vertexNormal_modelspace;
layout (location = 3) in vec3 vertexUV;

out vec3 UV;
out vec4 fragmentColor;
out vec3 Position_worldspace;
out vec3 Normal_cameraspace;
out vec3 EyeDirection_cameraspace;
out vec3 LightDirection_cameraspace;

uniform mat4 MVP;
uniform mat4 M;
uniform mat4 V;
uniform vec3 LightPosition_worldspace;

void main() {
  vec4 pos = MVP * vec4(vertexPosition_modelspace,1);
	gl_Position = pos.xyzw;
	
	Position_worldspace = (M * vec4(vertexPosition_modelspace,1)).xyz;
	vec3 vertexPosition_cameraspace = ( V * M * vec4(vertexPosition_modelspace,1)).xyz;
	EyeDirection_cameraspace = vec3(0,0,0) - vertexPosition_cameraspace;
	Normal_cameraspace = ( V * M * vec4(vertexNormal_modelspace,0)).xyz; // Only correct if ModelMatrix does not scale the model ! Use its inverse transpose if not.
	vec3 LightPosition_cameraspace = ( V * vec4(LightPosition_worldspace,1)).xyz;
	LightDirection_cameraspace = LightPosition_cameraspace + EyeDirection_cameraspace;

	fragmentColor = vertexColor;

	UV = vertexUV;
}
