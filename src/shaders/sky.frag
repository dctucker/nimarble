#version 330 core
out vec4 FragColor;

in vec3 TexCoords;

uniform samplerCube skybox;

void main()
{
	vec3 tex = texture(skybox, TexCoords).rgb;
	FragColor = vec4(tex * 0.25, 1.0);
}

