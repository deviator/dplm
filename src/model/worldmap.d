module model.worldmap;

import model.mapdata;

import des.math.linear;

interface WorldMap : Node
{
    alias Vector!(3,size_t,"w h d") mapsize_t;

    void setPoints( in vec3 from, in vec4[] pnts );

    mapsize_t size() const;

    final vec3 cellSize() const
    { return (matrix * vec4(1,1,1,0)).xyz; }
}
