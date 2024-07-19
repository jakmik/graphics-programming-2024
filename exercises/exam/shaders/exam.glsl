
// Uniforms
const int NVERTEX = 12;
const int NFACE = 20;
const float X = 0.525731112119133606;
const float Z = 0.850650808352039932;

vec3 vdata[NVERTEX] = vec3[](
   vec3(-X, 0.0, Z), vec3(X, 0.0, Z), vec3(-X, 0.0, -Z), vec3(X, 0.0, -Z),
   vec3(0.0, Z, X), vec3(0.0, Z, -X), vec3(0.0, -Z, X), vec3(0.0, -Z, -X),
   vec3(Z, X, 0.0), vec3(-Z, X, 0.0), vec3(Z, -X, 0.0), vec3(-Z, -X, 0.0)
);

ivec3 tindices[NFACE] = ivec3[](
   ivec3(0, 4, 1), ivec3(0, 9, 4), ivec3(9, 5, 4), ivec3(4, 5, 8), ivec3(4, 8, 1),
   ivec3(8, 10, 1), ivec3(8, 3, 10), ivec3(5, 3, 8), ivec3(5, 2, 3), ivec3(2, 7, 3),
   ivec3(7, 10, 3), ivec3(7, 6, 10), ivec3(7, 11, 6), ivec3(11, 0, 6), ivec3(0, 1, 6),
   ivec3(6, 1, 10), ivec3(9, 0, 11), ivec3(9, 11, 2), ivec3(9, 2, 5), ivec3(7, 2, 11)
);

uniform vec3 DiceColor = vec3(0, 1, 0);
uniform mat4 DiceMatrix = mat4(1, 0, 0, 0,   0, 1, 0, 0,   0, 0, 1, 0,   -3, -3, 0, 1);
uniform vec3 DiceSize = vec3(1, 1, 1);
uniform vec3 DiceCenter = vec3(0,0,0);
uniform float DiceRadius = 1.0f;

uniform vec3 LightColor = vec3(1.0f);
uniform float LightIntensity = 4.0f;
uniform vec2 LightSize = vec2(3.0f);

const vec3 CornellBoxSize = vec3(10.0f);

uniform mat4 ViewMatrix;

// Materials

struct Material
{
	vec3 albedo;
	float roughness;
	float metalness;
	float ior;
	vec3 emissive;
};

Material DiceMaterial = Material(DiceColor, /* roughness */0.5f, /* metalness */0.0f, /* ior */1.1f, /* emissive */vec3(0.0f));

Material CornellMaterial = Material(/* color */vec3(1.0f), /* roughness */0.75f, /* metalness */0.0f, /* ior */0.0f, /* emissive */vec3(0.0f));
Material LightMaterial = Material(vec3(0.0f), 0.0f, 0.0f, 0.0f, /* emissive */LightIntensity * LightColor);

// Forward declare ProcessOutput function
vec3 ProcessOutput(Ray ray, float distance, vec3 normal, Material material);

// Main function for casting rays: Defines the objects in the scene
vec3 CastRay(Ray ray, inout float distance)
{
	Material material;
	vec3 normal;

	// Cornell box
	if (RayBoxIntersection(ray, ViewMatrix, CornellBoxSize, distance, normal))
	{
		material = CornellMaterial;

		// Find local coordinates to paint the faces
		vec3 localPoint = TransformToLocalPoint(ray.point + ray.direction * distance, ViewMatrix);
		vec3 localPointAbs = abs(localPoint);

		// X axis: Left (red) and right (green)
		if (localPointAbs.x > localPointAbs.y && localPointAbs.x > localPointAbs.z)
			material.albedo = localPoint.x < 0 ? vec3(1.0f, 0.1f, 0.1f) : vec3(0.1f, 1.0f, 0.1f);
		// Y axis: Top (light)
		else if (localPoint.y > localPointAbs.x && localPoint.y > localPointAbs.z && localPointAbs.x < LightSize.x && localPointAbs.z < LightSize.y)
			material = LightMaterial;
		// Z axis: Front (black)
		else if (localPoint.z > localPointAbs.x && localPoint.z > localPointAbs.y)
			material.albedo = vec3(0);
	}
	
	if (RaySphereIntersection(ray, DiceCenter, DiceRadius, distance, normal)){
		{
			int shortestPathIndex;
			float shortestPath = 100f;
			for(int i=0;i<20;i++)
			{
			  vec1 v1 = tindices[i][0];
			  vec3 v2 = tindices[i][1];
			  vec3 v3 = tindices[i][2];
			  vec3 midPoint = (vdata[v1]+vdata[v2]+vdata[v3])/3;
			  dist = mp - ray.point();
			  if(shortestPath < dist){
				shortestPath = dist;
				shortestPathIndex = i;
			  }
			  
			}
			//Calculate if collides with plane
			if(intersects plane){
				material = DiceMaterial;
			}
		}
	}

	// Dice (20-sided)

	// We check if normal == vec3(0) to detect if there was a hit
	return dot(normal, normal) > 0 ? ProcessOutput(ray, distance, normal, material) : vec3(0.0f);
}

// Forward declare helper functions
vec3 GetAlbedo(Material material);
vec3 GetReflectance(Material material);
vec3 FresnelSchlick(vec3 f0, vec3 viewDir, vec3 halfDir);
vec3 GetDiffuseReflectionDirection(Ray ray, vec3 normal);
vec3 GetSpecularReflectionDirection(Ray ray, vec3 normal);
vec3 GetRefractedDirection(Ray ray, vec3 normal, float f);

// Creates a new derived ray using the specified position and direction
Ray GetDerivedRay(Ray ray, vec3 position, vec3 direction)
{
	return Ray(position, direction, ray.colorFilter, ray.ior);
}

// Produce a color value after computing the intersection
vec3 ProcessOutput(Ray ray, float distance, vec3 normal, Material material)
{
	// Find the position where the ray hit the surface
	vec3 contactPosition = ray.point + distance * ray.direction;

	// Compute the fresnel
	vec3 fresnel = FresnelSchlick(GetReflectance(material), -ray.direction, normal);

	// Compute transparency
	bool isTransparent = material.ior != 0.0f;
	bool isExit = ray.ior != 1.0f;
	float ior = mix(1.0f, material.ior, isTransparent && !isExit);
	vec3 refractedDirection = GetRefractedDirection(ray, normal, ray.ior / ior);

	// Add a ray to compute the diffuse lighting
	vec3 diffuseDirection = GetDiffuseReflectionDirection(ray, normal);
	Ray diffuseRay = GetDerivedRay(ray, contactPosition, isTransparent ? refractedDirection : diffuseDirection);
	if (!isExit)
	{
		diffuseRay.colorFilter *= GetAlbedo(material);
	}
	diffuseRay.colorFilter *= (1.0f - fresnel);
	diffuseRay.ior = ior;
	PushRay(diffuseRay);

	// Add a ray to compute the specular lighting
	float roughness = material.roughness * material.roughness;
	vec3 reflectedDirection = GetSpecularReflectionDirection(ray, normal);
	vec3 specularDirection = mix(reflectedDirection, diffuseDirection, roughness);
	Ray specularRay = GetDerivedRay(ray, contactPosition, specularDirection);
	specularRay.colorFilter *= fresnel;
	PushRay(specularRay);

	// Return emissive light, after applying the ray color filter
	return ray.colorFilter * material.emissive;
}

// Configure ray tracer
void GetRayTracerConfig(out uint maxRays)
{
	maxRays = 14u;
}

bool RayPlaneIntersection(vec3 rayOrigin, vec3 rayDir, vec3 planeNormal, vec3 planePoint, out float t) {
    // Calculate the denominator of the intersection formula
    float denom = dot(planeNormal, rayDir);
    
    // If denom is close to zero, the ray is parallel to the plane
    if (abs(denom) > 1e-6) {
        // Calculate the numerator of the intersection formula
        vec3 p0l0 = planePoint - rayOrigin;
        
        // Calculate the intersection parameter t
        t = dot(p0l0, planeNormal) / denom;
        
        // Return true if t is positive, meaning the intersection point is in front of the ray origin
        return (t >= 0);
    }
    
    // If denom is zero, there is no intersection
    return false;
}