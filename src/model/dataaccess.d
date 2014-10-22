module model.dataaccess;

import des.math.linear;

interface UnitDataAccess
{
    void updateMap( size_t no, in mat4 persp, float camfar, in mat4 transform, in float[] depth );
    vec3 nearestVolume( in vec3 pos );
    vec4[] getPoints( in vec3 pos, float dst );
}

interface ModelDataAccess : UnitDataAccess
{
    void setUnitCamResolution( in ivec2 res );
    void setUnitCount( size_t );

    alias Vector!(3,size_t,"w h d") mapsize_t;

    @property mapsize_t size() const;
    @property vec3 cellSize() const;
}
