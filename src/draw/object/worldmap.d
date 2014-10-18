module draw.object.worldmap;

public import draw.object.base;
import model.worldmap;

import std.conv;

class DrawWorldMap : BaseDrawObject
{
protected:
    GLBuffer data;
    int[3] mapsize;

    mat4 mapmtr;

public:

    this( Node p )
    {
        super( p, SS_WorldMap );
        clr = col4( 0,1,0, 1 );
        warn_if_empty = false;
    }

    void setData( WorldMap wm )
    in{ assert( wm !is null ); } body
    {
        mapsize = to!(int[3])(wm.vals.size);
        mapmtr = wm.matrix;
        data.setData( wm.vals.data, GLBuffer.Usage.DYNAMIC_DRAW );
    }

    override void draw( Camera cam )
    {
        shader.setUniformMat( "prj", cam(this) );
        shader.setUniform!int( "size_x", mapsize[0] );
        shader.setUniform!int( "size_y", mapsize[1] );
        shader.setUniform!float( "psize", 0.03 );

        drawArrays( DrawMode.POINTS );
    }

    override @property mat4 matrix() const
    { return super.matrix * mapmtr; }

protected:

    override void prepareBuffers()
    {
        auto b = createArrayBuffersFromAttributeInfo(
                APInfo( "data", "val", 1, GLType.FLOAT, WorldMap.Element.sizeof, 0 ),
                APInfo( "data", "prop", 1, GLType.FLOAT, WorldMap.Element.sizeof, float.sizeof, false ),
                );

        data = b["data"];
    }
}
