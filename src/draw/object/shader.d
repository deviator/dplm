module draw.object.shader;

public import des.gl.base;

enum SS_ShadeObject = staticLoadShaderSource!"glsl/shadeobject.glsl";
enum SS_Simple = staticLoadShaderSource!"glsl/simple.glsl";
enum SS_DepthPoint = staticLoadShaderSource!"glsl/depthpoint.glsl";
enum SS_WorldMap = staticLoadShaderSource!"glsl/worldmap.glsl";
enum SS_WorldMap_M = staticLoadShaderSource!"glsl/worldmap_light.glsl";
