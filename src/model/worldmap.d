module model.worldmap;

import model.mapdata;

import des.math.linear;
import des.il;

class WorldMap : Node
{
protected:

    static struct Element
    {
        float val = 0;
        float reliability = 0;
    }

    mat4 mtr;

    //MapData!(3,Element) vals;

public:

    this( ivec3 msize, mat4 transform )
    {
        mtr = transform;

        //vals.resize( msize );
    }

    @property const
    {
        mat4 matrix() { return mtr; }
        const(Node) parent() { return null; }
    }

    float minCellSize() const
    {
        auto mincell = (matrix * vec4(1,1,1,0)).xyz;
        auto minval = float.max;
        foreach( v; mincell.data )
            if( minval > v ) minval = v;
        return minval;
    }
}
